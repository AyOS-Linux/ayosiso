# AyOS Stuff 26.3

AyOS is an Arch Linux-based x86_64 distribution project. This repository contains the `archiso` profile, Calamares/Ayder integration, branding assets, and build/test scripts.

## Current scope

- Live installer desktop: KDE Plasma, SDDM, NetworkManager, PipeWire, codecs, and the **Ayder** installer.
- Installer: `ayder` from the AyOS repository (`https://ayos-linux.github.io/repo/x86_64`) — Calamares built in the repository cloud plus the AyOS packaging/branding. The local Calamares build pipeline was removed.
- No editions and no package selection: one build, KDE Plasma only. `shellprocess@pacstrap` installs a fixed package set.
- Calamares starts automatically on Live login (`/etc/xdg/autostart/calamares.desktop` → `pkexec calamares`).
- UEFI systemd-boot installation; Secure Boot is not configured.
- Release identity: AyOS Stuff 26.3.
- No telemetry is included.

## Build

On an Arch-based x86_64 build host, install `archiso`, `devtools`, `base-devel`, `git`, `qemu-desktop`, and `edk2-ovmf`, then run:

```bash
./build.sh iso
```

The build requires `sudo` (it cleans `work/`/`out/` from a previous run). Package cache, chroots, qcow2 test disks, and ISOs are intentionally excluded from Git. Build output is recorded in `build.log`.

## Test in QEMU

```bash
qemu-img create -f qcow2 ayos-test.qcow2 32G
./run-vm.sh live
```

See `docs/TESTING.md` for the installation and post-install verification checklist.

## Release artifacts

Do not commit ISO images to the Git repository. GitHub Release assets are limited to files under 2 GiB; if the ISO exceeds that limit, publish a `.iso.zst` asset plus a SHA-256 checksum and extraction instructions. Only publish after completing the VM test matrix.

## License

Project-wide licensing is not yet selected. Do not redistribute this repository and build images publicly until the owner has chosen a license and verified permissions for the supplied logo/wallpaper and third-party components. See `THIRD-PARTY.md`.
