#!/usr/bin/env bash
# Apply the nx591j Sailfish OS patches on top of a synced hybris-14.1 tree.
# Usage: scripts/apply-patches.sh /path/to/android/tree
set -euo pipefail
TREE=${1:?usage: $0 ANDROID_ROOT}
REPO=$(cd "$(dirname "$0")/.." && pwd)

# patches/<dir>  ->  path inside the Android tree
declare -A TARGET=(
    [bionic]=bionic
    [system_core]=system/core
    [hybris-boot]=hybris/hybris-boot
    [device_nubia_msm8976-common]=device/nubia/msm8976-common
    [hardware_qcom_display-caf_msm8952]=hardware/qcom/display-caf/msm8952
    [droidmedia]=external/droidmedia
    [kernel_nubia_msm8976]=kernel/nubia/msm8976
    [sensorfw]=hybris/mw/sensorfw          # cloned by build_packages.sh --mw
    [libhybris]=hybris/mw/libhybris/libhybris
    [sailfish-fpd-community]=hybris/mw/sailfish-fpd-community   # git clone, see README
)

for dir in "${!TARGET[@]}"; do
    dst=$TREE/${TARGET[$dir]}
    if [ ! -d "$dst" ]; then
        echo "skip $dir: $dst not present yet (middleware is cloned by build_packages.sh --mw)"
        continue
    fi
    echo "== $dir -> ${TARGET[$dir]}"
    git -C "$dst" -c user.name=nx591j -c user.email=nx591j@localhost am -3 "$REPO/patches/$dir"/*.patch
done

# 32-bit audio bridge for the 64-bit PulseAudio (see "Porting notes" in README.md)
mkdir -p "$TREE/hybris/nubia-audio"
cp "$REPO"/android/nubia-audio/* "$TREE/hybris/nubia-audio/"
echo "done"
