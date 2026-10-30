# Sailfish OS for Nubia Z17 Lite (NX591J)

Community port of [Sailfish OS](https://sailfishos.org) 5.1 to the **ZTE Nubia Z17 Lite (NX591J)**.

| | |
|---|---|
| SoC | Qualcomm Snapdragon 653 (MSM8976SG), 4× Cortex-A72 + 4× Cortex-A53 |
| RAM / storage | 6 GB / 64 GB eMMC |
| Android base | hybris-14.1 (LineageOS 14.1 / Android 7.1) |
| Kernel | 3.10.84, [HighwayStar/android_kernel_nubia_msm8976](https://github.com/HighwayStar/android_kernel_nubia_msm8976) `staging/cm-14.1-nx591j` + patches in this repo |
| Sailfish OS | 5.1.0.11, **aarch64** |

> **Status: early, works as a daily-ish device without camera/Bluetooth.** See [Hardware status](#hardware-status).

## Contents

* [Hardware status](#hardware-status)
* [Installing](#installing)
* [Building](#building)
* [Porting notes](#porting-notes) – every problem found and how it was fixed
* [Repository layout](#repository-layout)

## Hardware status

Sailfish OS 5.1.0.11 aarch64, hybris-14.1. Last checked 2026-10-30.

| Area | Status | Notes |
|---|---|---|
| Boot, systemd, Android services | ✅ | |
| Display, UI (lipstick), apps | ✅ | needs `nx591j-extras` (TLS fix) and the libhybris gralloc patch |
| Touch, on-screen keyboard | ✅ | |
| Capacitive keys | ✅ | left = back, middle/right = home; haptics via `nubia-keyhaptic` |
| Brightness | ✅ | |
| Vibration / haptics | ✅ | effect lengths raised (motor ignores pulses < ~40 ms) |
| Wi-Fi | ✅ | built-in Pronto driver started by `wlan-pronto-start.service` |
| Browser incl. video (YouTube) | ✅ | needs `mediacodec` / `mediaextractor` services |
| Speaker audio | ✅ | 32-bit audio bridge, see [Porting notes](#audio) |
| Microphone | ✅ | same bridge, capture direction |
| Volume keys | ✅ | |
| Sensors | ✅ | accelerometer, magnetometer, gyroscope (sensorfw patched for Android 7) |
| Camera | ⚠️ | app starts; preview slow, capture fails (`Camera2Client: notifyError`), video recording hangs |
| Wired headphones (USB-C analog adapter) | ❓ | untested; the bridge switches routes via the "Headset Jack" input device |
| Bluetooth | ❌ | kernel lacks `hci_smd` (BlueZ ↔ WCN3680 SMD); `bluetooth.service` also needs group `uhid` |
| Fingerprint | ❌ | not investigated (did not work on LineageOS 14.1 either) |
| Rear camera colour | ⚠️ | on LineageOS the default rear camera is the monochrome sensor |
| Calls, SMS, mobile data | ❓ | untested (no SIM); RIL is up (`rild`, `ofonod`) |
| GPS | ❓ | untested |
| Earpiece routing in calls | ❓ | untested; the audio bridge only handles media routes yet |

## Installing

> **Back up first.** Unlocking the bootloader and installing Sailfish OS wipes user data.
> A full eMMC dump over Qualcomm EDL (e.g. `bkerler/edl` with the ZTE MSM8976 loader
> `009900e100040000_fdfc20db73081ea0_fhprg_peek.bin`) lets you restore everything,
> including the device unique partitions (`modemst1/2`, `fsg`, `persist`).

### Bootloader

```sh
adb reboot bootloader
fastboot oem nubia_unlock NUBIA_NX591J
```

The Nubia bootloader **re-locks on every reboot** (the unlock counter persists, the flag does
not). Run `nubia_unlock` again in the same fastboot session before every flash. A re-locked
bootloader still boots the custom images.

### 1. LineageOS 14.1 base

Sailfish OS uses the Android vendor blobs from the `system` partition, so LineageOS 14.1
(built from the same device tree) must be flashed first:

```sh
fastboot oem nubia_unlock NUBIA_NX591J
fastboot flash recovery recovery.img
fastboot flash boot boot.img
fastboot flash system system.img
fastboot erase cache
fastboot erase userdata          # NOT "fastboot format": it leaves no room for the crypto footer
fastboot reboot
```

### 2. Sailfish OS

`userdata` must be unencrypted ext4 (LineageOS encrypts it on first boot).

**Recovery:** *Factory reset → Format data*, then *Apply update → Apply from ADB*:

```sh
adb sideload sailfishos-nx591j-release-5.1.0.11-nx591j1-signed.zip
```

**Or fastboot:** build an ext4 userdata image with the rootfs extracted to
`/.stowaways/sailfishos` and flash it together with `hybris-boot.img`. Use `mke2fs` with
lazy inode table init / `uninit_bg` – an image full of FILL chunks takes ~100 minutes to flash.

### Getting a shell

After boot the device exposes RNDIS networking over USB:

```sh
sudo ip addr add 192.168.2.1/24 dev <usb-interface>
telnet 192.168.2.15 2323        # root shell (debug init)
```

`touch /init_enter_debug2` stops the next boot before systemd.

### Back to stock

Restore the EDL dump (`edl wl <dir> --skip=userdata` keeps the device unique partitions
untouched), or flash the stock `boot`/`system` from it and erase `userdata`.

## Building

The build follows the [Sailfish OS HADK](https://hadk.sailfishos.org/) with a few
device specific steps. Tested on Arch Linux with Docker; ~70 GB of free disk space needed.

### 1. Android side (hybris-14.1)

Build environment: Ubuntu 18.04 container with OpenJDK 8 and git-lfs
(`scripts/Dockerfile.android-build`).

```sh
docker build -t los14-build -f scripts/Dockerfile.android-build scripts/
mkdir -p ~/hadk/.repo/local_manifests
cp manifest/nx591j.xml ~/hadk/.repo/local_manifests/
docker run --rm -v ~/hadk:/src los14-build bash -c '
  cd /src
  repo init -u https://github.com/mer-hybris/android -b hybris-14.1 --depth=1
  repo sync -c -j8 --no-tags --no-clone-bundle'
scripts/apply-patches.sh ~/hadk        # everything except sensorfw (see step 2)
```

Build (`scripts/buduj-hybris.sh` does the same inside the container):

```sh
source build/envsetup.sh
lunch lineage_nx591j-userdebug
make -j6 hybris-hal libdroidmedia minimediaservice minisfservice libminisf \
    libaudioflingerglue libaudioflingerglue_32 miniafservice \
    hwcomposer.msm8952 gralloc.msm8952 copybit.msm8952 memtrack.msm8952 \
    nubia-audiobridge nubia-audiotest nubia-audiorec
```

Notes:
* `droidmedia` is not a make target on this base – build its modules explicitly (above).
* The display HALs **must** come from this tree: the ones on the LineageOS `/system`
  are built from newer cm-14.1 sources and crash with the hybris `libbinder`.
* `external/droidmedia` needs full git history (`git fetch --unshallow --tags`) for packaging.
* Android 7 on Ubuntu 18.04: `LC_ALL=C`, and TLSv1 re-enabled in `java.security` for Jack.

### 2. Sailfish OS side (Platform SDK)

Platform SDK 5.1.0.11 with an `aarch64` target named `nubia-nx591j-aarch64`.
`mb2`/scratchbox2 only sees `$HOME`, so the Android tree must live under it
(`ANDROID_ROOT=$HOME/hadk`).

```sh
# ~/.hadk.env
export ANDROID_ROOT=$HOME/hadk VENDOR=nubia DEVICE=nx591j PORT_ARCH=aarch64

cp -r droid-hal/* $ANDROID_ROOT/rpm/                       # + git submodule dhd
cp -r droid-config/* $ANDROID_ROOT/hybris/droid-configs/   # + submodule droid-configs-device
cp -r droid-hal-version/* $ANDROID_ROOT/hybris/droid-hal-version-nx591j/

rpm/dhd/helpers/build_packages.sh --droid-hal
rpm/dhd/helpers/build_packages.sh --configs
rpm/dhd/helpers/build_packages.sh --mw        # clones middleware, sensorfw fails here:
scripts/apply-patches.sh $ANDROID_ROOT        #   apply sensorfw + libhybris patches, then
rpm/dhd/helpers/build_packages.sh -o --mw     #   rebuild offline (keeps the patches)
rpm/dhd/helpers/build_packages.sh -o --gg
rpm/dhd/helpers/build_packages.sh -o --version
# extras: build extras/rpm/nx591j-extras.spec with mb2 and add it to the local repo
RELEASE=5.1.0.11 EXTRA_NAME=-nx591j1 rpm/dhd/helpers/build_packages.sh -o --mic
```

### 3. Installation zip

The LineageOS 14.1 recovery only accepts zips signed with its key (AOSP test-keys for an
unofficial build). Sign the image zip with `scripts/sign_ota.py` (whole-file signature,
same format as `signapk -w`), see [Installing](#installing).

## Porting notes

Problems hit while bringing Sailfish OS 5.1 (aarch64) up on a hybris-14.1 / kernel 3.10
base, in the order they appeared. Symptom → cause → fix. Many of these are not specific to
the Nubia and will bite any 64-bit port on an Android 7 base.

### Kernel

**`mer_verify_kernel_config` errors.** Enabled DEVTMPFS(+MOUNT), FHANDLE, IKCONFIG(+PROC),
TMPFS_POSIX_ACL, QUOTA*, UTS/IPC/PID/NET_NS, VT, AUTOFS4, CGROUP_DEVICE/PERF, MEMCG,
CHECKPOINT_RESTORE, WATCHDOG_NOWAYOUT; disabled DUMMY and ANDROID_PARANOID_NETWORK.
`selinux=0 audit=0` on the kernel command line.

**Build fails with MEMCG=y:** duplicate `mem_cgroup_allow_attach()` in `mm/memcontrol.c`
(vendor leftover outside the `CONFIG_MMU` blocks) → removed.

**Panic ~60 s after boot:** `netns cleanup_net → nf_conntrack_cleanup_net_list →
kmem_cache_destroy → sysfs_remove_one → BUG`. The per-netns conntrack slab is named
`nf_conntrack_%pK`; once Android sets `kptr_restrict=2`, `%pK` prints zeros, so every new
network namespace (systemd `PrivateNetwork=`, firejail `net none`) got the same slab name and
the sysfs entries collided. Fix: name the slab with a counter. (Disabling NET_NS hides the
panic but breaks every sandboxed app without the Internet permission – firejail fails with
`clone: Invalid argument`.)

**Panic after ~30 min of heavy I/O:** `mmc_blk_cmdq_issue_rq` BUG in eMMC command queueing →
`CONFIG_MMC_CQ_HCI` disabled.

**Capacitive keys:** reported as KEY_MENU (left), KEY_HOMEPAGE (middle), KEY_BACK (right)
(`synaptics,cap-button-codes` in `touch.dtsi`). Remapped to back/home/home. Lipstick only
handles the home key if `/usr/share/csd/settings.d/*hw-settings*.ini` has
`[Keys] Keys=0x01000090,0x01000061` – **numeric** Qt key codes, names are not parsed.

### Android init (droid-hal-init)

**`Failed to initialize property area`:** bionic `system_properties.cpp` treats a failing
`fsetxattr(security.selinux)` as fatal; with `selinux=0` the kernel returns EOPNOTSUPP.
Patched bionic to ignore EOPNOTSUPP there.

**No Android services start:** `init_user0` in `init.rc` runs `vdc --wait cryptfs init_user0`,
which waits forever for `vold` (not used on Sailfish OS) and blocks the trigger chain before
`on boot`. Removed. Also: dhd deletes `fstab.*`, so `mount_all` fails and the
`nonencrypted` trigger never fires → `trigger nonencrypted` added after `mount_all`.

**Services from the LineageOS `/system/etc/init/*.rc` are never started** – hybris init only
reads `/usr/libexec/droid-hybris/system/etc/init`. Missing ones had to be added there:
`logd.rc` (otherwise no logcat at all), `mediacodec.rc`, `mediaextractor.rc` (CameraService
and Gecko wait forever for `media.codec` / `media.extractor`), and `miniaf.rc`
(audioflingerglue `miniafservice` – CameraService waits for `media.audio_flinger`).

**USB:** `init.qcom.usb.rc` fights `usb_moded` over the gadget – import removed.

### Graphics

**hwcomposer crashes in `Parcel::unflatten_binder`:** the display HALs on `/system` come
from LineageOS (newer cm-14.1 sources) and carry inlined `Parcel`/`sp<>` code that does not
match the hybris `libbinder`. Build `hwcomposer/gralloc/copybit/memtrack.msm8952` (+
libqdutils, libqservice, liboverlay, …) in the hybris tree; libhardware looks in
`/usr/libexec/droid-hybris/system/lib64/hw` first. The legacy `libhwcomposer` needs
`libmedia`/`libskia` (not in the trimmed hybris manifest) only for debug dumps and a media
death notifier → `HYBRIS_NO_MEDIA` patch.

**lipstick crashes in `QObject::event` / `moveToThread`** right after the EGL stack loads:
on aarch64, Android 7 bionic code (libEGL, Adreno) writes its TLS slots at fixed offsets
from `tpidr_el0` (e.g. tp+24, OPENGL_API tp+48, OPENGL tp+56), which in glibc is the start
of the static TLS block – where Qt keeps its per-thread data. Fix: `libtlspad.so`
(256-byte initial-exec `__thread` array) loaded first via `/etc/ld.so.preload`, so the
bionic slots land in padding. Verified with gdb (pointer into an `[anon:.bss]` mapping at
tp+24).

**Every app crashes in `gralloc_register_buffer` (`private_handle_t::validate`):** libhybris
`gralloc.c` calls `native_handle_clone()`, which Android 7 headers do not declare; C assumes
`int` and truncates the 64-bit pointer (x0 = 0x7c156700). Added the prototype. Invisible on
32-bit ports.

### Audio

**PulseAudio hangs at start, `ADM open timedout` / `pcm_prepare returned -1`:** the 64-bit
audio HAL + ACDB blobs do not work (anc_cal ioctl EFAULT, AFE custom topologies -18, ADSP
rejects ADM open on QUIN_MI2S). Android 7 runs `audioserver` **32-bit** by default
(empty `AUDIOSERVER_MULTILIB`), so only the 32-bit HAL was ever tested by the vendor.
Fix: `nubia-audiobridge`, a small 32-bit native program that opens the HAL and moves PCM
through FIFOs: PulseAudio `module-pipe-sink` → `/run/nubia-audio/fifo` → HAL output;
HAL input → `/run/nubia-audio/mic` → `module-pipe-source`. HAL output goes to standby after
0.5 s of silence; the mic is only captured while someone reads the FIFO.

PulseAudio details:
* `xpolicy.conf` selects devices by **properties**, not names – the pipe sink needs
  `droid.output.primary/media_latency/low_latency=true`, otherwise everything is routed to
  `sink.null`.
* `module-pipe-source` refuses a FIFO created by another user, and several properties in
  one `source_properties=` break the parser → let PulseAudio create the mic FIFO, set one
  property at load time and the rest with `update-source-proplist`.
* PulseAudio recreates the FIFOs on restart – the bridge reopens them when the inode changes.

**Speaker amplifier (TAS2555) firmware not loaded:** the firmware request comes ~0.3 s before
`/system` is mounted and `droid-load-firmware.sh` gives up at once → it now waits up to 30 s.
Never rebind the codec at runtime to retry: it leaves stale DAPM pointers and panics in
`snd_soc_dapm_set_bias_level`.

### Other

* **Wi-Fi:** the Pronto WLAN driver is built in and only starts after
  `echo sta > /sys/module/wlan/parameters/fwpath`.
* **Haptics:** `native-vibrator` writes `/sys/class/timed_output/vibrator/enable`; default
  touch effects (5–30 ms) are too short for this motor. The capacitive keys produce no ngfd
  events at all → `nubia-keyhaptic` reads the input device directly.
* **sensorfw** uses Android 8 `sensors.h` names → compat defines.
* **droidmedia** sets `layerCount`, which exists only on Android ≥ 8.
* **droid-configs** template ships `/etc/ofono/binder.conf`, which conflicts with
  `ofono-configs-binder` → removed via `delete_file.list`.
* `syscall 293` (rseq) and other ENOSYS messages in dmesg are noise: kernel 3.10 lacks
  rseq/memfd/etc. and glibc falls back.

### Debugging tips

* With `logd.rc` in place, `/system/bin/logcat` works; HAL errors only show up there.
* Kernel panics land in pstore (`mount -t pstore pstore /mnt`, `console-ramoops-0`).
  After a panic the phone sits in Qualcomm download mode (`19d2:ffae`) – hold power.
* If the device panics within a minute of boot, catch the debug telnet
  (`scripts/zlap-telnet.sh`) and stop the offending services, or `touch /init_enter_debug2`.
* Android executables can be run directly from the Sailfish shell (32-bit ones too) – handy
  for testing HALs in isolation (`android/nubia-audio/audiotest.cpp`).
* `gdb` + `info proc mappings` and the symbol files in `out/target/product/*/symbols`
  (mind the first `LOAD` vaddr when converting offsets) resolve crashes in Android libraries.

## Repository layout

```
manifest/            local manifest for the hybris-14.1 tree (device, common tree, kernel, vendor)
patches/<project>/   patches for bionic, system/core, hybris-boot, libhybris, display-caf,
                     droidmedia, sensorfw, msm8976-common and the kernel
droid-hal/           droid-hal-nx591j.spec (dhd as submodule)
droid-config/        droid-config-nx591j (spec, patterns, sparse/ with all runtime fixes)
droid-hal-version/   droid-hal-version-nx591j.spec
android/nubia-audio/ 32-bit audio bridge (PulseAudio <-> Android audio HAL) + test tools
extras/              nx591j-extras: TLS fix (libtlspad), haptics for the capacitive keys
scripts/             build container, build/flash/diagnostic helpers, OTA zip signing
```

The kernel with all Sailfish OS changes is kept as a separate repository
([kopebax/android_kernel_nubia_msm8976](https://github.com/kopebax/android_kernel_nubia_msm8976), branch `sfos-hybris-14.1`); the same commits are in `patches/kernel_nubia_msm8976/`.

## Credits

* [HighwayStar](https://github.com/HighwayStar) – LineageOS device tree, kernel and vendor repos for the Nubia MSM8976 family
* [mer-hybris](https://github.com/mer-hybris) / [Sailfish OS](https://github.com/sailfishos) – HADK, libhybris, droid-hal-device and middleware
* LineageOS

## License

Code in this repository (audio bridge, extras, scripts, packaging) is under the
[BSD 3-Clause License](LICENSE). Files in `patches/` modify third-party projects and are
under the license of the project they apply to (Linux kernel: GPL-2.0, AOSP/LineageOS:
Apache-2.0, libhybris: Apache-2.0/LGPL, …). Vendor blobs are not part of this repository.
