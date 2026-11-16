#!/usr/bin/env bash
# AyOS Stuff 26.3 — build.sh
# Сборка ISO через mkarchiso. Установщик приходит готовым пакетом ayder из
# репозитория AyOS (https://ayos-linux.github.io/repo/x86_64): он уже содержит
# Calamares, собранный в облаке репозитория, и пак оформления (branding ayder).
# Локальная сборка Calamares в chroot (старая стадия repo, /opt/ayos-local-repo)
# удалена вместе с «Local-Calamares Installer».
#
# Использование:
#   ./build.sh iso      — собрать ISO (то же, что ./build.sh all)
#   ./build.sh clean    — удалить work/ и out/ (спрашивает подтверждение)

set -euo pipefail

# Чистое окружение для сборки: хост-десктоп-переменные (LD_PRELOAD и т.п.)
# не должны протекать в pacstrap/mkarchiso/chroot-процессы.
unset LD_PRELOAD LD_AUDIT XDG_CURRENT_DESKTOP QT_QPA_PLATFORMTHEME 2>/dev/null || true

# Каталог репозитория = место, где лежит сам build.sh (работает и в ~/AyOS,
# и в ~/ayosiso; переопределить можно переменной окружения AYOS_DIR=...)
AYOS_DIR="${AYOS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
LOG="$AYOS_DIR/build.log"
AYOS_REPO_URL="https://ayos-linux.github.io/repo/x86_64"

log() { printf '[build] %s\n' "$*" | tee -a "$LOG"; }
die() { printf '[build] FATAL: %s\n' "$*" | tee -a "$LOG" >&2; exit 1; }

# Имя/версия ISO читаются из profiledef.sh — источник истины один.
# Вывод: первая строка iso_name, вторая — iso_version.
# ВАЖНО: file_permissions надо заранее объявить ассоциативным (как это делает
# mkarchiso: `declare -A file_permissions=()`), иначе bash трактует
# ["/etc/shadow"]="0:0:400" как арифметический индекс и sourcing падает с
# "arithmetic syntax error", не дойдя до printf.
iso_meta() {
  (
    declare -A file_permissions=()
    # shellcheck disable=SC1091
    source "$AYOS_DIR/releng/profiledef.sh"
    printf '%s\n%s\n' "$iso_name" "$iso_version"
  )
}

require_host_tools() {
  command -v mkarchiso >/dev/null || die "mkarchiso not found (pacman -S archiso)"
  [[ -d "$AYOS_DIR/releng" ]] || die "$AYOS_DIR/releng missing"
  # Инфраструктура установщика ayder обязана быть на месте:
  grep -q '^\[ayos\]' "$AYOS_DIR/releng/pacman.conf" \
    || die "releng/pacman.conf: нет секции [ayos] ($AYOS_REPO_URL)"
  grep -qx 'ayder' "$AYOS_DIR/releng/packages.x86_64" \
    || die "releng/packages.x86_64: нет пакета ayder"
  [[ -f "$AYOS_DIR/releng/airootfs/etc/xdg/autostart/calamares.desktop" ]] \
    || die "нет autostart-записи для Calamares (etc/xdg/autostart/calamares.desktop)"
}

# ── mkarchiso ───────────────────────────────────────────────────────
build_iso() {
  require_host_tools

  local meta iso_name iso_version
  mapfile -t meta < <(iso_meta)
  iso_name="${meta[0]}"
  iso_version="${meta[1]}"

  log "=== iso stage: AyOS Stuff $iso_version ($AYOS_REPO_URL) ==="
  cd "$AYOS_DIR"

  # work-каталог прошлой сборки содержит root-владельческие файлы (pacstrap),
  # поэтому чистим через sudo. Разрушительное действие: каталоги сборки AyOS.
  if [[ -d work || -d out ]]; then
    sudo rm -rf "$AYOS_DIR/work" "$AYOS_DIR/out"
  fi
  mkdir -p work out

  # Кэш пакетов: mkarchiso работает без root (pacstrap -N), системный
  # /var/cache/pacman/pkg ему не записать — pacman пишет warning
  # "couldn't find or create package cache, using /tmp/" и теряет скачанное
  # при прерывании/ребуте (это tmpfs). mkarchiso сохраняет профильный CacheDir
  # (_make_pacman_conf), поэтому даём постоянный пользовательский каталог:
  # докачанные пакеты переживают прерванные запуски.
  local pkg_cache="${AYOS_PKG_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/ayos/pacman}"
  local iso_pacman_conf="$pkg_cache/iso.pacman.conf"
  mkdir -p "$pkg_cache"
  sed 's|^\[options\]$|[options]\nCacheDir = '"$pkg_cache"'|' \
      "$AYOS_DIR/releng/pacman.conf" > "$iso_pacman_conf"
  grep -qF "CacheDir = $pkg_cache" "$iso_pacman_conf" \
    || die "failed to set CacheDir in $iso_pacman_conf"

  # mkarchiso сам выполняет customize_airootfs.sh в chroot
  local log_start
  log_start=$(wc -l < "$LOG")
  mkarchiso -v -C "$iso_pacman_conf" -w "$AYOS_DIR/work" -o "$AYOS_DIR/out" "$AYOS_DIR/releng" 2>&1 | tee -a "$LOG"
  if sed -n "$((log_start + 1)),\$p" "$LOG" | grep -Eq 'ERROR: binary not found|Failed to install packages|errors were encountered during the build'; then
    die "mkarchiso log contains a package/initramfs error; do not use this ISO"
  fi

  local iso="$AYOS_DIR/out/${iso_name}-${iso_version}-x86_64.iso"
  [[ -s "$iso" ]] || die "mkarchiso did not produce a non-empty ISO at $iso"
  file "$iso" | grep -q 'ISO 9660' || die "output is not a valid ISO 9660 image: $iso"

  log "ISO built:"
  ls -la "$AYOS_DIR/out" | tee -a "$LOG"
  sha256sum "$iso" | tee -a "$LOG"
  log "СБОРКА ЗАВЕРШЕНА: $iso"
}

case "${1:-iso}" in
  iso|all) build_iso ;;
  clean)
        echo "Удалить $AYOS_DIR/work и $AYOS_DIR/out? [y/N]"
        read -r answer
        [[ "$answer" == "y" ]] && { sudo rm -rf "$AYOS_DIR/work" "$AYOS_DIR/out"; echo "cleaned"; }
        ;;
  repo)
        echo "Стадия repo удалена: Calamares ставится пакетом ayder из $AYOS_REPO_URL" >&2
        exit 0
        ;;
  *)    echo "usage: $0 {iso|clean}" >&2; exit 1 ;;
esac
