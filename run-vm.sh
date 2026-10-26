#!/usr/bin/env bash
# AyOS Material 26.11 — run-vm.sh
# Запуск тестовой виртуалки: UEFI (OVMF), KVM, 4G RAM, наш ISO, qcow2-диск.
#
# Использование:
#   ./run-vm.sh              — Live-тест (загрузка с ISO)
#   ./run-vm.sh disk         — загрузка с установленного диска (после установки)
#   ./run-vm.sh uefi-shell   — встроенный UEFI Shell (проверка ESP)

set -euo pipefail
cd "$HOME/AyOS"

ISO="out/ayos-26.11-x86_64.iso"
DISK="ayos-test.qcow2"
OVMF_DIR="/usr/share/edk2/x64"

# Постоянные NVRAM-переменные для этой VM (boot-записи сохраняются между запусками)
[[ -f OVMF_VARS.fd ]] || cp "$OVMF_DIR/OVMF_VARS.4m.fd" OVMF_VARS.fd
# Live-boot gets a separate clean NVRAM, so stale boot entries cannot mask the ISO.
[[ -f OVMF_VARS_LIVE.fd ]] || cp "$OVMF_DIR/OVMF_VARS.4m.fd" OVMF_VARS_LIVE.fd

case "${1:-live}" in
  live)
    # Свежий NVRAM на КАЖДЫЙ запуск live: если в прошлом пуске из Live делали
    # установку, efibootmgr записал в NVRAM «Linux Boot Manager» (ESP диска) и
    # поднял его в BootOrder — тогда OVMF грузил бы диск вместо ISO. Шаблон
    # NVRAM сбрасывает BootOrder: первой снова становится CD (-boot order=d).
    VARS_FILE=OVMF_VARS_LIVE.fd
    rm -f OVMF_VARS_LIVE.fd
    cp "$OVMF_DIR/OVMF_VARS.4m.fd" OVMF_VARS_LIVE.fd
    MODE=(-boot order=d,menu=on -drive if=none,id=ayoscd,file="$ISO",media=cdrom,readonly=on -device ide-cd,drive=ayoscd,bus=ahci.0,bootindex=0)
    ;;
  disk)
    VARS_FILE=OVMF_VARS.fd
    MODE=(-boot order=c)
    ;;
  uefi-shell)
    VARS_FILE=OVMF_VARS_LIVE.fd
    # Вход в UEFI Shell по ESC -> Boot Manager
    MODE=()
    ;;
  *)
    echo "usage: $0 {live|disk|uefi-shell}" >&2; exit 1 ;;
esac

# virtio-net: полноценный гигабитный паравиртуальный адаптер (быстрее и
# надёжнее e1000). Live использует NetworkManager — он сам поднимает DHCP.
exec qemu-system-x86_64 \
  -enable-kvm \
  -m 3193 -smp 4 \
  -machine q35 -cpu host \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_DIR/OVMF_CODE.4m.fd" \
  -drive if=pflash,format=raw,file="$VARS_FILE" \
  -device ich9-ahci,id=ahci \
  -drive if=none,id=ayosdisk,file="$DISK",format=qcow2 \
  -device virtio-blk-pci,drive=ayosdisk,bootindex=1 \
  "${MODE[@]}" \
  -display gtk,gl=on \
  -device virtio-vga-gl \
  -device qemu-xhci -device usb-kbd -device usb-tablet \
  -netdev user,id=net0,restrict=off,host=10.0.2.2,dns=10.0.2.3 \
  -device virtio-net-pci,netdev=net0 \
  -audiodev pa,id=snd0 -device ich9-intel-hda -device hda-output,audiodev=snd0
