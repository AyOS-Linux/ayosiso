# AyOS Material 26.11

AyOS is an Arch Linux-based x86_64 distribution project. This repository contains the `archiso` profile, Calamares configuration, branding assets, and build/test scripts.

## Current scope

- Live installer desktop: KDE Plasma, SDDM, NetworkManager, PipeWire, codecs, and Calamares.
- Calamares edition chooser: Everyday (Plasma), Light (Xfce), Angel (niri + AngelOS dotfiles), Barebone (TTY), and Nebula (GNOME).
- UEFI systemd-boot installation; Secure Boot is not configured.
- Release identity: AyOS Material 26.11.
- No telemetry is included.

## Build

On an Arch-based x86_64 build host, install `archiso`, `devtools`, `base-devel`, `git`, `qemu-desktop`, and `edk2-ovmf`. Configure the local Calamares package repository as described in `docs/BUILD.md`, then run:

```bash
./build.sh repo
./build.sh iso
```

Build output, package caches, chroots, qcow2 test disks, and ISOs are intentionally excluded from Git. The script records build output in `build.log`.

## Test in QEMU

```bash
qemu-img create -f qcow2 ayos-test.qcow2 32G
./run-vm.sh live
```

See `docs/TESTING.md` for the installation and post-install verification checklist.

## Release artifacts

Do not commit ISO images to the Git repository. GitHub Release assets are limited to files under 2 GiB; if the ISO exceeds that limit, publish a `.iso.zst` asset plus a SHA-256 checksum and extraction instructions. Only publish after completing the VM test matrix.

## License

Project-wide licensing is not yet selected. Do not redistribute this repository or build images publicly until the owner has chosen a license and verified permissions for the supplied logo/wallpaper and third-party components. See `THIRD-PARTY.md`.
