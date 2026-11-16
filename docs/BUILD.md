# Build AyOS Stuff 26.3

## Requirements

Build on Arch Linux or an Arch-based x86_64 system with `archiso`, `devtools`, `base-devel`, `git`, `qemu-desktop`, and `edk2-ovmf` installed. Do not install Calamares on the host just to test it; test the generated ISO in QEMU. The build uses `sudo` to clean `work/` and `out/`.

## Installer: Ayder from the AyOS repository

Calamares is not in the Arch official repositories and is no longer built locally: the old `./build.sh repo` stage (AUR PKGBUILD → chroot → `/opt/ayos-local-repo`) was removed together with the profile's own `/etc/calamares` tree.

The installer now comes from the AyOS repository:

```ini
# releng/pacman.conf
[ayos]
Server = https://ayos-linux.github.io/repo/$arch
SigLevel = Optional TrustAll
```

`ayder` is listed in `releng/packages.x86_64`. The package ships the Calamares binary (`provides/conflicts: calamares`), the AyOS branding (`/etc/calamares/branding/ayder`) and the complete configuration: `settings.conf`, locale/partition/users/bootloader module configs and the shellprocess instances used at install time (`ayos_osrelease`, `ayos_edition`, `pacstrap`).

Because `mkarchiso` copies `profile/airootfs` **before** installing packages, no file under `releng/airootfs/etc/calamares` may exist — a duplicate would collide with `ayder` and abort `pacstrap` with `exists in filesystem`. The build refuses to start if `ayder` or the `[ayos]` entry is missing.

Where the `[ayos]` entry ends up:

- `releng/pacman.conf` is used **only while the image is built** — that is how `pacstrap` downloads `ayder`. It cannot be shipped as `releng/airootfs/etc/pacman.conf`: `/etc/pacman.conf` belongs to the `pacman` package and would collide exactly like `ayder` did.
- `customize_airootfs.sh` appends `[ayos]` to the Live system's `/etc/pacman.conf` (it runs after `pacstrap`).
- `/usr/local/bin/ayos-edition` runs **inside** the target chroot (`dontChroot: false`) and appends the same section to the installed system, because `ayder`'s `pacstrap` does not pass `-P` — without it `pacstrap` does not copy the host config into the target.

What the profile still provides to the installer:

- `/usr/local/bin/ayos-osrelease` and `/usr/local/bin/ayos-edition` (KDE-only; `ayos-edition` accepts exactly `everyday`, the name hardcoded in `ayder`'s config),
- `/usr/share/backgrounds/ayos`, `/etc/skel` Plasma config, `/etc/systemd/zram-generator.conf` (copied into the target by `shellprocess@pacstrap`),
- `polkit` rule allowing `liveuser` to run `pkexec /usr/bin/calamares` without a password,
- `/etc/xdg/autostart/calamares.desktop` — Calamares starts automatically after login.

There are no editions and no package-selection step: `settings.conf` from `ayder` shows `locale → partition → users → summary` and installs a fixed KDE Plasma set via `pacstrap`.

## Commands

```bash
./build.sh iso
```

`./build.sh clean` asks before removing only the `work` and `out` directories inside the detected repository root.

The repository root is detected from the location of `build.sh` itself, so the checkout can live anywhere (`~/ayosiso`, `~/AyOS`, ...); override it with `AYOS_DIR=/path/to/checkout ./build.sh ...`. The ISO name and version are read from `releng/profiledef.sh` (`ayos-stuff-26.3-x86_64.iso`).

The ISO is considered successful only if mkarchiso returns success and produces a nonempty ISO-9660 file. Inspect `build.log` for the full build output.
