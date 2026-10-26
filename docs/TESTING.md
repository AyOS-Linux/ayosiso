# AyOS release test checklist

Run all installation tests in disposable QEMU VMs. Do not test Calamares by installing to the host.

## Live boot

- UEFI boot through OVMF, no Secure Boot.
- SDDM automatically logs into `liveuser` without a password.
- KDE Plasma starts, AyOS wallpaper appears, and the Calamares launcher opens.
- NetworkManager, Bluetooth, PipeWire, and fastfetch work.
- Calamares starts without initialization/module errors and shows all five editions.

## Edition install matrix

For every edition, use the disposable `ayos-test.qcow2` disk and verify installation completes, systemd-boot starts the system, hostname/locale/timezone are applied, and `/etc/os-release` reports the matching AyOS `PRETTY_NAME`.

| Edition | Post-install checks |
|---|---|
| Everyday | Plasma, Dolphin, Konsole, Kate, Discover, SDDM |
| Light | Xfce, Thunar, xfce4-terminal, Mousepad, LightDM |
| Angel | niri session, Quickshell and AngelOS dotfiles installed noninteractively for the Calamares user |
| Barebone | TTY default target, NetworkManager, nano, base-devel, git |
| Nebula | GNOME, Nautilus, GNOME Terminal, Gedit, GNOME Software, GDM |

Also verify `fastfetch` displays `/usr/share/ayos/logo.txt` where fastfetch is installed. Record failures from Calamares logs and `journalctl -b` before preparing a public release.
