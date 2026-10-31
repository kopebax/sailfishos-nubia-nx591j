#!/usr/bin/env bash
# Make the LineageOS 14.1 recovery usable for installing Sailfish OS:
#  * androidboot.selinux=permissive – with SELinux enforcing the hybris updater gets
#    "Permission denied" writing /data/.stowaways ("Failed to extract filesystem!")
#  * /misc in fstab.qcom – Android 7 bootloader_message looks /misc up in
#    /fstab.<ro.hardware>, not in etc/recovery.fstab ("failed to find /misc partition",
#    factory reset from the OS does not work)
# Usage: recovery-sfos.sh <lineage recovery.img> <output.img>
# Needs mkbootimg/unpack_bootimg (AOSP mkbootimg tools), cpio, gzip.
set -euo pipefail
in=${1:?usage: $0 recovery.img out.img}; out=${2:?usage: $0 recovery.img out.img}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
unpack_bootimg --boot_img "$in" --out "$tmp/u" > "$tmp/info"
cmdline=$(sed -n 's/^command line args: //p' "$tmp/info")
mkdir "$tmp/rd"
(cd "$tmp/rd" && gzip -dc ../u/ramdisk | cpio -id --quiet)
grep -q ' /misc ' "$tmp/rd/fstab.qcom" ||
    echo '/dev/block/bootdevice/by-name/misc          /misc               emmc    defaults                                                                 defaults' >> "$tmp/rd/fstab.qcom"
case " $cmdline " in *" androidboot.selinux=permissive "*) ;; *) cmdline="$cmdline androidboot.selinux=permissive" ;; esac
(cd "$tmp/rd" && find . | LC_ALL=C sort | cpio -o -H newc -R 0:0 --quiet | gzip -9 > ../ramdisk)
mkbootimg --header_version 0 --kernel "$tmp/u/kernel" --ramdisk "$tmp/ramdisk" \
    --pagesize 2048 --base 0 --kernel_offset 0x80008000 --ramdisk_offset 0x81000000 \
    --second_offset 0 --tags_offset 0x80000100 --cmdline "$cmdline" -o "$out"
echo "$out: $cmdline"
