# GitHub organization and release

## Repository

The project organization already exists at <https://github.com/AyOS-Linux>. The source repository is `AyOS-Linux/AyOS`. Push the source/profile only; `.gitignore` deliberately excludes build trees, local packages, VM disks, build logs, and ISO files.

## Release asset size

GitHub Releases reject individual assets at or above 2 GiB. The ISO is larger than that limit and squashfs is already compressed, so extra compression may not bring it under the cap. Split the ISO into two parts below 2 GiB each, publish their checksums, and provide reconstruction instructions. Do not publish until all five QEMU installation tests pass and the owner has confirmed redistribution rights for the supplied logo/wallpaper assets and AngelOS-derived content.

Example after the final ISO has passed tests:

```bash
split -b 1900M -d -a 2 out/ayos-26.11-x86_64.iso out/ayos-26.11-x86_64.iso.part-
sha256sum out/ayos-26.11-x86_64.iso.part-* > out/ayos-26.11-x86_64.parts.sha256
stat -c '%s %n' out/ayos-26.11-x86_64.iso.part-*
```

Each part must be less than `2147483648` bytes. Upload both parts and the checksum file to the GitHub Release for tag `26.11`. Users reconstruct with `cat ayos-26.11-x86_64.iso.part-* > ayos-26.11-x86_64.iso` and verify the reconstructed ISO checksum against a separately published checksum generated with `sha256sum out/ayos-26.11-x86_64.iso`.
