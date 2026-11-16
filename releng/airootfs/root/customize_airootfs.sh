#!/usr/bin/env bash
# AyOS Stuff 26.3 — customize_airootfs.sh
# Выполняется mkarchiso в chroot airootfs после pacstrap.
# Задачи: os-release AyOS Stuff (Live), motd, сервисы Live.
# Установщик — пакет ayder из репы https://ayos-linux.github.io/repo/x86_64
# (Calamares собран в облаке репозитория); локального Calamares здесь нет.

set -euo pipefail

log() { printf '[AyOS-customize] %s\n' "$*" ; }

# ── 1a. Права на AyOS-хелперы ─────────────────────────────────────
# mkarchiso копирует profile/airootfs с --no-preserve=ownership,mode,
# из-за этого exec-биты сброшены; восстанавливаем 0755 до упаковки в squashfs.
log "restoring exec bits on ayos helpers"
chmod 0755 \
  /usr/local/bin/ayos-edition \
  /usr/local/bin/ayos-osrelease

# ── 1. os-release AyOS Stuff (Live) ────────────────────────────────
# Финальный PRETTY_NAME установленной системы пишет ayos-osrelease
# (shellprocess@ayos_osrelease из конфига ayder). Редакций нет: только KDE.
log "writing /etc/os-release"
cat > /etc/os-release <<'EOF'
NAME="AyOS Stuff"
PRETTY_NAME="AyOS Stuff 26.3 (Live)"
ID=ayos
ID_LIKE=arch
BUILD_ID=26.3
VARIANT_ID=live-kde
VARIANT="Live (KDE Plasma)"
HOME_URL="https://github.com/AyOS-Linux/ayosiso"
DOCUMENTATION_URL="https://github.com/AyOS-Linux/ayosiso/wiki"
LOGO=ayos
EOF
chmod 644 /etc/os-release

# Репозиторий AyOS ([ayos] -> https://ayos-linux.github.io/repo/$arch).
# /etc/pacman.conf в Live приходит из ПАКЕТА pacman: в airootfs такого файла
# нет сознательно — mkarchiso копирует профиль ДО pacstrap, и свой конфиг
# конфликтовал бы с пакетом ("exists in filesystem"), как это делал ayder.
# Поэтому секцию добавляем здесь, ПОСЛЕ pacstrap.
if grep -q '^\[ayos\]' /etc/pacman.conf; then
  log "[ayos] repository already present in /etc/pacman.conf"
else
  cat >> /etc/pacman.conf <<'EOF'

# === AyOS repo: ayder (установщик) и пакеты AyOS ===
# https://ayos-linux.github.io/repo/x86_64
[ayos]
Server = https://ayos-linux.github.io/repo/$arch
SigLevel = Optional TrustAll
EOF
  log "added [ayos] repository to /etc/pacman.conf"
fi

# ── 2. fastfetch: кастомизации убраны (решение владельца).
# fastfetch живёт дефолтной жизнью; логотип придёт upstream-PR'ом.

# ── 2a. Патч Presentation.qml (баг slideshow в Calamares + Qt 6.9+) ─
# Апстрим использует deprecated-инжект параметра в signal-хэндлер
# (onClicked: { if (mouse.button ...) }), который Qt 6.9+ уже не
# подставляет: хэндлер падает и слайдшоу Calamares не листается.
# Фикс по совету варнинга - формальный параметр стрелки.
# Файл ставит пакет ayder (проверено: паттерн в его Presentation.qml есть).
QMLDIR=/usr/share/calamares/qml/calamares/slideshow
if [[ -f "$QMLDIR/Presentation.qml" ]] && grep -q "onClicked: {" "$QMLDIR/Presentation.qml"; then
  perl -0pi -e 's/onClicked: \{(\s+if \(mouse\.button)/onClicked: (mouse) => {$1/' \
    "$QMLDIR/Presentation.qml"
  log "patched Presentation.qml (deprecated signal injection)"
fi

# ── 3. motd AyOS Stuff вместо Arch-справки ─────────────────────────
log "writing /etc/motd"
cat > /etc/motd <<'EOF'
AyOS Stuff 26.3 — Live medium (KDE Plasma)

  Установщик Ayder (Calamares) запускается АВТОМАТИЧЕСКИ после входа в сессию.
  Если закрыли — запустите снова: ярлык "Install AyOS Stuff" или из терминала:
      pkexec calamares
  Сети пока нет? NetworkManager поднимется сам (nmcli / nm-connection-editor).
  О системе: fastfetch

  Редакций нет: ставится одна сборка с KDE Plasma, выбора пакетов нет.

Домашняя страница: https://github.com/AyOS-Linux/ayosiso
EOF

# ── 5. Пользователь Live-сессии: passwordless + autologin (решение владельца) ──
log "creating liveuser (no password)"
if ! id liveuser &>/dev/null; then
  useradd -m -G wheel,video,audio,optical,storage -s /bin/bash liveuser
  # Пустой пароль: разрешает безпарольный вход и безпарольный sudo
  passwd -d liveuser
fi
# passwordless sudo для liveuser (нужно для запуска Calamares)
echo 'liveuser ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/liveuser
chmod 440 /etc/sudoers.d/liveuser
# Do not leave the inherited releng root account with an empty password.
passwd -l root
# Пустые пароли должны быть разрешены для входа (nullok) — SDDM/pam
sed -i 's/^#\?nullok.*/nullok/' /etc/pam.d/system-auth 2>/dev/null || true
sed -i 's/^#*nullok.*/nullok/' /etc/pam.d/system-local-login 2>/dev/null || true

# ── 6. Сервисы Live-сессии ────────────────────────────────────────
log "enabling Live services (SDDM autologin)"
systemctl enable NetworkManager.service bluetooth.service sddm.service 2>/dev/null || true
systemctl enable pacman-init.service 2>/dev/null || true

log "customize_airootfs finished"

exit 0
