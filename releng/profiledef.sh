#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="ayos"
iso_label="AYOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="AyOS <https://github.com/AyOS-Linux/ayosiso>"
iso_application="AyOS Material Live Media"
iso_version="26.11"
install_dir="ayos"
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# AyOS §4: ускоренная сборка — все ядра CPU, zstd уровень 15, блок 1M, без append
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '3' '-b' '1M' '-processors' "$(nproc)" '-noappend' '-e' 'var/cache/pacman/pkg/*' '-e' 'usr/share/doc/*')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
kernel_params_aarch64="clk_ignore_unused pd_ignore_unused arm64.nopauth"
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
)
