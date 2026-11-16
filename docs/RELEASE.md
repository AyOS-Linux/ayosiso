# GitHub organization and release

## Repository

The project organization already exists at <https://github.com/AyOS-Linux>. The source repository is `AyOS-Linux/ayosiso`. Push the source/profile only; `.gitignore` deliberately excludes build trees, local packages, VM disks, build logs, and ISO files.

## Release asset size

GitHub Releases reject individual assets at or above 2 GiB. The ISO is larger than that limit and squashfs is already compressed, so extra compression may not bring it under the cap. Split the ISO into two parts below 2 GiB each, publish their checksums, and provide reconstruction instructions. Do not publish until the QEMU installation test passes and the owner has confirmed redistribution rights for the supplied logo/wallpaper assets.

Example after the final ISO has passed tests:

```bash
cd out
rm -rf split && mkdir split
split -b 1600M ayos-stuff-26.3-x86_64.iso split/ayos-stuff-26.3-x86_64.iso.
sha256sum ayos-stuff-26.3-x86_64.iso split/ayos-stuff-26.3-x86_64.iso.aa split/ayos-stuff-26.3-x86_64.iso.ab
```

`split` без `-d` даёт суффиксы `.aa`/`.ab` (порядок по алфавиту), а `1600M`
= 1 677 721 600 байт, то есть каждая часть заметно ниже лимита GitHub в
`2147483648` байт. Загрузите обе части на GitHub Release для тега
`26.3`. Пользователь собирает образ обратно и сверяет контрольную сумму:

```bash
cat ayos-stuff-26.3-x86_64.iso.aa ayos-stuff-26.3-x86_64.iso.ab > ayos-stuff-26.3-x86_64.iso
sha256sum ayos-stuff-26.3-x86_64.iso
```

Перед публикацией обязательно проверьте, что склейка байт-в-байт совпала
с оригиналом (`cmp rebuilt.iso ayos-stuff-26.3-x86_64.iso`).
