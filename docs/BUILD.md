# Build AyOS Material

## Requirements

Build on Arch Linux or an Arch-based x86_64 system with `archiso`, `devtools`, `base-devel`, `git`, `qemu-desktop`, and `edk2-ovmf` installed. Do not install Calamares on the host just to test it; test the generated ISO in QEMU.

## Calamares package

Calamares is not in the Arch official repositories. Build the project-approved AUR PKGBUILD in a clean `devtools` chroot and make sure the `packagechooser` module is not excluded from the build. Put the resulting `calamares` package into `/opt/ayos-local-repo` and update its database with `repo-add`. The ISO profile uses this repository only during image construction; the customize step removes the local repository entry from the Live system's pacman configuration.

The build script uses `luts` for privileged operations, defaults to half the logical CPU count for package builds, and lowers CPU/I/O scheduling priority. Override the job count with `JOBS=4 ./build.sh repo`.

## Commands

```bash
./build.sh repo
./build.sh iso
```

`./build.sh clean` asks before removing only `~/AyOS/work` and `~/AyOS/out`.

The ISO is considered successful only if mkarchiso returns success and produces a nonempty ISO-9660 file. Inspect `build.log` for the full build output.
