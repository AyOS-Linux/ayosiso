# AyOS Stuff release test checklist

Run all installation tests in disposable QEMU VMs. Do not test Calamares by installing to the host.

## Live boot

- UEFI boot through OVMF, no Secure Boot.
- SDDM automatically logs into `liveuser` without a password.
- KDE Plasma starts and the AyOS wallpaper appears.
- Calamares (Ayder) opens **automatically** about 6 seconds after login, without a password prompt (polkit rule for `liveuser`).
- NetworkManager, Bluetooth, PipeWire, and fastfetch work.
- Calamares starts without initialization/module errors and shows exactly four steps: `locale → partition → users → summary`. No package selection, no edition chooser.

## Install check

Use the disposable `ayos-test.qcow2` disk and verify installation completes, systemd-boot starts the system, hostname/locale/timezone are applied, and `/etc/os-release` reports `PRETTY_NAME="AyOS Stuff 26.3"`.

Post-install checks:

- Plasma, Dolphin, Konsole, Kate, Discover, SDDM
- No Xfce/GNOME packages, no LightDM/GDM
- `/etc/pacman.conf` keeps the `[ayos]` repository
- `ayder`/`calamares` is not installed on the target (the installer stays Live-only)

Also verify `fastfetch` displays `/usr/share/ayos/logo.txt` where fastfetch is installed. Record failures from Calamares logs and `journalctl -b` before preparing a public release.
