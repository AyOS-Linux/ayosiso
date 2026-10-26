#!/usr/bin/env bash
# AyOS Material 26.11 — build.sh
# Полный цикл: (0) проверка окружения, (1) сборка AUR-пакетов в изолированном
# chroot -> /opt/ayos-local-repo, (2) mkarchiso, (3) отчёт.
# Хост не загрязняется: все сборки в chroot; лог в ~/AyOS/build.log.
#
# Использование:
#   ./build.sh repo      — опубликовать уже собранный Calamares в локальную репу
#   ./build.sh iso       — собрать ISO (требует готовой репы)
#   ./build.sh all       — repo + iso
#   ./build.sh clean     — удалить work-директорию (запрашивает подтверждение)

set -euo pipefail

# Чистое окружение для сборки: хост-десктоп-переменные (LD_PRELOAD AngelOS и т.п.)
# не должны протекать в pacstrap/mkarchiso/chroot-процессы.
unset LD_PRELOAD LD_AUDIT XDG_CURRENT_DESKTOP QT_QPA_PLATFORMTHEME 2>/dev/null || true

AYOS_DIR="$HOME/AyOS"
REPO_DIR="$AYOS_DIR/repo"                     # staging AUR-пакетов
CHROOT_DIR="$AYOS_DIR/chroot"                 # изолированное chroot-окружение сборки
LOCAL_REPO="/opt/ayos-local-repo"             # финальная репа (нужен luts для записи)
# AUR-пакеты: только calamares (в официальных репах Arch его НЕТ).
# quickshell и niri теперь в [extra] — AUR-сборка не нужна.
AUR_PKGS=(calamares)
LOG="$AYOS_DIR/build.log"

log() { printf '[build] %s\n' "$*" | tee -a "$LOG"; }
die() { printf '[build] FATAL: %s\n' "$*" | tee -a "$LOG" >&2; exit 1; }

require_host_tools() {
  command -v mkarchiso >/dev/null || die "mkarchiso not found"
  command -v pacstrap >/dev/null  || die "pacstrap not found (arch-install-scripts)"
  command -v systemd-nspawn >/dev/null || die "systemd-nspawn not found"
  [[ -d "$AYOS_DIR/releng" ]] || die "$AYOS_DIR/releng missing"
}

sync_calamares_config() {
  local dst="$AYOS_DIR/releng/airootfs/etc/calamares"
  log "syncing Calamares configuration into airootfs"
  mkdir -p "$dst/modules" "$dst/branding/ayos/images"
  cp "$AYOS_DIR/calamares/settings.conf" "$dst/settings.conf"
  cp "$AYOS_DIR/calamares/modules/"*.conf "$dst/modules/"
  # не-.conf ассеты модулей (ayos-netinstall.yaml — groupsUrl читает
  # file:///etc/calamares/ayos-netinstall.yaml, то есть РЯДОМ с conf'ами)
  cp "$AYOS_DIR/calamares/modules/"*.yaml "$dst/" 2>/dev/null || true
  # python-модули (подкаталоги src): Calamares 3.4 ищет ДЕСКРИПТОР+скрипт
  # в системном каталоге /usr/lib/calamares/modules — "local" в modules-search
  # на /etc/calamares/modules дескрипторы НЕ смотрит (проверено отлупом
  # "not found in module search paths"). Конфиг модуля, наоборот, ищется
  # уровнем выше: /etc/calamares/modules/<имя>.conf — как у стоковых.
  local sysmod="$AYOS_DIR/releng/airootfs/usr/lib/calamares/modules"
  mkdir -p "$sysmod"
  for d in "$AYOS_DIR/calamares/modules/"*/; do
    [[ -d "$d" ]] || continue
    local name
    name="$(basename "$d")"
    if [[ -f "$d/module.desc" ]]; then
      rm -rf "$sysmod/$name"
      mkdir -p "$sysmod/$name"
      cp "$d/module.desc" "$sysmod/$name/"
      cp "$d"/*.py "$sysmod/$name/" 2>/dev/null || true
      rm -rf "$sysmod/$name/__pycache__"
    fi
    if [[ -f "$d/$name.conf" ]]; then
      cp "$d/$name.conf" "$dst/modules/$name.conf"
    fi
  done
  cp "$AYOS_DIR/calamares/branding/ayos/branding.desc" \
     "$AYOS_DIR/calamares/branding/ayos/show.qml" "$dst/branding/ayos/"
  cp "$AYOS_DIR/calamares/branding/ayos/images/"* "$dst/branding/ayos/"
  cp "$AYOS_DIR/calamares/branding/ayos/"*.png "$dst/branding/ayos/"
}

# ── (1) AUR -> local repo, в изолированном chroot ──────────────────
build_repo() {
  log "=== repo stage: building ${AUR_PKGS[*]} in chroot ==="
  mkdir -p "$REPO_DIR"

  # Скачиваем PKGBUILD'ы (не собираем на хосте)
  for p in "${AUR_PKGS[@]}"; do
    [[ -d "$REPO_DIR/$p" ]] || git clone --depth 1 "https://aur.archlinux.org/$p.git" "$REPO_DIR/$p"
  done

  # The AUR Calamares PKGBUILD skips packagechooser by default. AyOS requires
  # the standard Qt Widgets packagechooser module; retain packagechooserq skip.
  if [[ -f "$REPO_DIR/calamares/PKGBUILD" ]]; then
    sed -i '/^[[:space:]]*packagechooser[[:space:]]*$/d' "$REPO_DIR/calamares/PKGBUILD"
    grep -q 'packagechooser' "$REPO_DIR/calamares/PKGBUILD" || \
      die "Calamares PKGBUILD does not enable packagechooser"
  fi

  # Chroot devtools: <CHROOT_DIR>/root создаётся mkarchroot (нужен luts)
  if [[ ! -d "$CHROOT_DIR/root" ]]; then
    log "creating build chroot at $CHROOT_DIR/root (requires luts)..."
    luts mkdir -p "$CHROOT_DIR"
    luts mkarchroot "$CHROOT_DIR/root" base-devel git
  fi

  # Ускорение/разгрузка сборки (§4): MAKEFLAGS настраивается в chroot-копии makepkg.conf.
  # JOBS можно переопределить: JOBS=4 ./build.sh repo
  # По умолчанию — половина ядер: ноутбук не «страдает» и остаётся отзывчивым.
  JOBS="${JOBS:-$(( $(nproc) / 2 ))}"
  if [[ -f "$CHROOT_DIR/root/etc/makepkg.conf" ]]; then
    luts sed -i "s/^#\?MAKEFLAGS=.*/MAKEFLAGS=\"-j${JOBS}\"/" "$CHROOT_DIR/root/etc/makepkg.conf"
    log "MAKEFLAGS=-j${JOBS} applied to chroot makepkg.conf"
  fi

  # makechrootpkg запускается ИЗ каталога с PKGBUILD;
  # nice/ionice — сборка не мешает работе десктопа; -c: чистая копия chroot.
  for p in "${AUR_PKGS[@]}"; do
    # пропускаем уже собранные (calamares уже готов — не пересобираем)
    if find "$REPO_DIR/$p" -maxdepth 1 -name '*.pkg.tar.zst' | grep -q .; then
      log "$p: package already built, skipping"
      continue
    fi
    log "building $p in chroot (-j${JOBS}, nice 10)..."
    ( cd "$REPO_DIR/$p" && luts nice -n 10 ionice -c3 makechrootpkg -c -r "$CHROOT_DIR" ) || die "makechrootpkg failed for $p"
    [[ -n $(find "$REPO_DIR/$p" -maxdepth 1 -name '*.pkg.tar.zst' | head -1) ]] || die "$p: no package built"
  done

  # Публикация в локальную репу (нужен luts — файлы вне ~/AyOS)
  log "publishing packages to $LOCAL_REPO..."
  luts mkdir -p "$LOCAL_REPO"
  find "$REPO_DIR" -maxdepth 2 -name '*.pkg.tar.zst' ! -name '*-debug-*' -exec luts cp -t "$LOCAL_REPO" {} +
  luts repo-add "$LOCAL_REPO/ayos-local.db.tar.gz" "$LOCAL_REPO"/*.pkg.tar.zst

  log "repo stage done:"
  ls -la "$LOCAL_REPO" | tee -a "$LOG"
}

# ── (2) mkarchiso ──────────────────────────────────────────────────
build_iso() {
  require_host_tools
  log "=== iso stage: mkarchiso ==="
  sync_calamares_config
  cd "$AYOS_DIR"
  # work-каталог прошлой сборки содержит root-владельческие файлы (pacstrap),
  # поэтому чистим через luts. Разрушительное действие: каталоги сборки AyOS.
  if [[ -d work || -d out ]]; then
    luts rm -rf "$AYOS_DIR/work" "$AYOS_DIR/out"
  fi
  mkdir -p work out
  # mkarchiso сам выполняет customize_airootfs.sh в chroot
  local log_start
  log_start=$(wc -l < "$LOG")
  mkarchiso -v -w "$AYOS_DIR/work" -o "$AYOS_DIR/out" "$AYOS_DIR/releng" 2>&1 | tee -a "$LOG"
  if sed -n "$((log_start + 1)),\$p" "$LOG" | grep -Eq 'ERROR: binary not found|Failed to install packages|errors were encountered during the build'; then
    die "mkarchiso log contains a package/initramfs error; do not use this ISO"
  fi
  local iso="$AYOS_DIR/out/ayos-26.11-x86_64.iso"
  [[ -s "$iso" ]] || die "mkarchiso did not produce a non-empty ISO (pacstrap/customize may have failed)"
  file "$iso" | grep -q 'ISO 9660' || die "output is not a valid ISO 9660 image: $iso"
  log "ISO built:"
  ls -la "$AYOS_DIR/out" | tee -a "$LOG"
}

case "${1:-all}" in
  repo) require_host_tools; build_repo ;;
  iso)  build_iso ;;
  all)  require_host_tools; build_repo; build_iso ;;
  clean)
        echo "Удалить ~/AyOS/work и ~/AyOS/out? [y/N]"
        read -r answer
        [[ "$answer" == "y" ]] && { luts rm -rf "$AYOS_DIR/work" "$AYOS_DIR/out"; echo "cleaned"; }
        ;;
  *)    echo "usage: $0 {repo|iso|all|clean}" >&2; exit 1 ;;
esac
