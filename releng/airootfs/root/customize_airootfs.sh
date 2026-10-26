#!/usr/bin/env bash
# AyOS Material 26.11 — customize_airootfs.sh
# Выполняется mkarchiso в chroot airootfs после pacstrap.
# Задачи: os-release AyOS (Live), motd, сервисы Live.

set -euo pipefail

log() { printf '[AyOS-customize] %s\n' "$*" ; }

# ── 1a. Права на AyOS-хелперы ─────────────────────────────────────
# mkarchiso копирует profile/airootfs с --no-preserve=ownership,mode,
# из-за этого exec-биты сброшены; восстанавливаем 0755 до упаковки в squashfs.
log "restoring exec bits on ayos helpers"
chmod 0755 \
  /usr/local/bin/ayos-edition \
  /usr/local/bin/ayos-osrelease \
  /usr/local/bin/ayos-angelos

# ── 1. os-release AyOS (Live) ──────────────────────────────────────
# Финальный PRETTY_NAME по редакции задаётся post-install скриптом Calamares.
log "writing /etc/os-release"
cat > /etc/os-release <<'EOF'
NAME="AyOS"
PRETTY_NAME="AyOS v26.11 (Live)"
ID=ayos
ID_LIKE=arch
BUILD_ID=26.11
VARIANT_ID=live-kde
VARIANT="Live (KDE Plasma)"
HOME_URL="https://github.com/AyOS-Linux/ayosiso"
DOCUMENTATION_URL="https://github.com/AyOS-Linux/ayosiso/wiki"
LOGO=ayos
EOF
chmod 644 /etc/os-release

# Локальный repo нужен только mkarchiso/pacstrap для установки Calamares в Live.
# Установленная система не содержит /opt/ayos-local-repo, поэтому не оставляем
# недоступный file://-репозиторий в pacman.conf целевой системы.
if grep -q '^\[ayos-local\]' /etc/pacman.conf; then
  sed -i '/^\[ayos-local\]/,/^$/d' /etc/pacman.conf
fi

# ── 2. fastfetch: кастомизации убраны (решение владельца).
# fastfetch живёт дефолтной жизнью; логотип придёт upstream-PR'ом.

# ── 2a. Патч Presentation.qml (баг calamares 3.4.2 + Qt 6.9+) ──────
# Апстрим использует deprecated-инжект параметра в signal-хэндлер
# (onClicked: { if (mouse.button ...) }), который Qt 6.9+ уже не
# подставляет: хэндлер падает и слайдшоу Calamares не листается.
# Фикс по совету варнинга - формальный параметр стрелки.
QMLDIR=/usr/share/calamares/qml/calamares/slideshow
if [[ -f "$QMLDIR/Presentation.qml" ]] && grep -q "onClicked: {" "$QMLDIR/Presentation.qml"; then
  perl -0pi -e 's/onClicked: \{(\s+if \(mouse\.button)/onClicked: (mouse) => {$1/' \
    "$QMLDIR/Presentation.qml"
  log "patched Presentation.qml (deprecated signal injection)"
fi

# ── 3. motd AyOS вместо Arch-справки ──────────────────────────────
log "writing /etc/motd"
cat > /etc/motd <<'EOF'
AyOS Material 26.11 — Live medium (KDE Plasma)

  Calamares установлен. Запуск установщика: ярлык "Install System" (pkexec)
  или из терминала: sudo calamares
  Сеть: NetworkManager (nmcli / nm-connection-editor)
  О системе: fastfetch

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
