# Sailfish OS for Nubia Z17 Lite (NX591J)

Community port of [Sailfish OS](https://sailfishos.org) 5.1 to the **ZTE Nubia Z17 Lite (NX591J)**.

| | |
|---|---|
| SoC | Qualcomm Snapdragon 653 (MSM8976SG), 4× Cortex-A72 + 4× Cortex-A53 |
| RAM / storage | 6 GB / 64 GB eMMC |
| Android base | hybris-14.1 (LineageOS 14.1 / Android 7.1) |
| Kernel | 3.10.84, [HighwayStar/android_kernel_nubia_msm8976](https://github.com/HighwayStar/android_kernel_nubia_msm8976) `staging/cm-14.1-nx591j` + patches in this repo |
| Sailfish OS | 5.1.0.11, **aarch64** |
| Status | daily driver except the camera – see [Hardware status](#hardware-status) |

## Contents

| Section | What is there |
|---|---|
| [Hardware status](#hardware-status) | what works, what does not |
| [Installing](#installing) | bootloader, LineageOS base, recovery, Sailfish OS |
| [Building](#building) | Android side, Sailfish OS packages, image |
| [Porting notes](#porting-notes) | every problem found: symptom → cause → fix |
| [Packages](#packages) | what each port package contains |
| [Repository layout](#repository-layout) | directories of this repository |

## Hardware status

Sailfish OS 5.1.0.11 aarch64, hybris-14.1. Last checked 2026-10-31 on a fresh install.

| Area | Status | Notes |
|---|---|---|
| Boot, systemd, Android services | ✅ | |
| Display, UI (lipstick), apps | ✅ | TLS fix (`libtlspad`), libhybris gralloc patch |
| Touch, on-screen keyboard | ✅ | |
| Capacitive keys | ✅ | left = back, middle/right = home, with haptics |
| Brightness, volume keys | ✅ | |
| Vibration / haptics | ✅ | longer effects (motor ignores pulses < ~40 ms) |
| Battery level, charging | ✅ | |
| Screen rotation, sensors | ✅ | accelerometer, magnetometer, gyroscope, light, proximity |
| Wi-Fi | ✅ | |
| Browser incl. video (YouTube) | ✅ | |
| Speaker, microphone | ✅ | 32-bit audio bridge |
| Wired headphones (USB-C) | ✅ | |
| Bluetooth | ✅ | incl. A2DP speakers |
| Calls | ✅ | earpiece, speaker, mute; Bluetooth HFP untested |
| SMS, mobile data | ✅ | dual SIM |
| GPS | ✅ | faster fix with XTRA: Settings → Location → "Enable extra online based assistance" |
| Fingerprint | ✅ | add and unlock; no Gatekeeper (unsigned auth token) |
| Chum, Pure Maps | ✅ | preinstalled |
| Recovery | ✅ | patched LineageOS recovery: `/misc` found, `/data` writable; full zip install through it not re-tested yet |
| Camera | ⚠️ | app starts; preview slow, capture fails, video recording hangs |
| Rear camera colour | ⚠️ | on LineageOS the default rear camera is the monochrome sensor |

## Installing

> **Back up first.** Unlocking the bootloader and installing Sailfish OS wipes user data.
> A full eMMC dump over Qualcomm EDL (e.g. `bkerler/edl` with the ZTE MSM8976 loader
> `009900e100040000_fdfc20db73081ea0_fhprg_peek.bin`) lets you restore everything,
> including the device unique partitions (`modemst1/2`, `fsg`, `persist`).

| Step | Commands / actions | Notes |
|---|---|---|
| 1. Unlock | `adb reboot bootloader`<br>`fastboot oem nubia_unlock NUBIA_NX591J` | Re-locks on **every** reboot: repeat in the same fastboot session before each flash. A re-locked bootloader still boots custom images. |
| 2. LineageOS 14.1 base | `fastboot flash boot boot.img`<br>`fastboot flash system system.img`<br>`fastboot erase cache`<br>`fastboot erase userdata` | Sailfish OS uses the vendor blobs on `system`. Use `erase`, **not** `format` (no room for the crypto footer). |
| 3. Recovery | `scripts/recovery-sfos.sh recovery.img recovery-sfos.img`<br>`fastboot flash recovery recovery-sfos.img` | The stock LineageOS recovery cannot install Sailfish OS (see [Recovery](#recovery)). |
| 4. Format data | Recovery: *Factory reset → Format data* | `userdata` must be unencrypted ext4. |
| 5. Install | Recovery: *Apply update → Apply from ADB*<br>`adb sideload sailfishos-nx591j-release-5.1.0.11-nx591j3-signed.zip` | Zip signed with the AOSP test key (`scripts/sign_ota.py`). |
| 6. First boot | *Reboot system now* | One-time setup takes a few minutes before the setup wizard. |

### Shell access

| What | How |
|---|---|
| USB network (RNDIS) | `sudo ip addr add 192.168.2.1/24 dev <usb-interface>` |
| Root shell, running system | `telnet 192.168.2.15 2323` |
| Root shell, initramfs (no rootfs / debug) | `telnet 192.168.2.15 23` |
| Stop the next boot before systemd | `touch /init_enter_debug2` |

### Back to stock

Restore the EDL dump (`edl wl <dir> --skip=userdata` keeps the device unique partitions
untouched), or flash the stock `boot`/`system` from it and erase `userdata`.

## Building

Follows the [Sailfish OS HADK](https://hadk.sailfishos.org/) with a few device specific
steps. Tested on Arch Linux with Docker; ~70 GB of free disk space needed.

| Environment | Details |
|---|---|
| Android build | Ubuntu 18.04 container, OpenJDK 8, git-lfs (`scripts/Dockerfile.android-build`); `LC_ALL=C`, TLSv1 re-enabled in `java.security` for Jack |
| Sailfish OS build | Platform SDK 5.1.0.11, target `nubia-nx591j-aarch64`; the Android tree must live under `$HOME` (`ANDROID_ROOT=$HOME/hadk`) – scratchbox2 only sees `$HOME` |
| `~/.hadk.env` | `export ANDROID_ROOT=$HOME/hadk VENDOR=nubia DEVICE=nx591j PORT_ARCH=aarch64` |

### 1. Android side (hybris-14.1)

```sh
docker build -t los14-build -f scripts/Dockerfile.android-build scripts/
mkdir -p ~/hadk/.repo/local_manifests
cp manifest/nx591j.xml ~/hadk/.repo/local_manifests/
docker run --rm -v ~/hadk:/src los14-build bash -c '
  cd /src
  repo init -u https://github.com/mer-hybris/android -b hybris-14.1 --depth=1
  repo sync -c -j8 --no-tags --no-clone-bundle'
# fingerprint daemon + its Android side (libbiometry_fp_api), patched for the legacy HAL
git clone https://github.com/piggz/sailfish-fpd-community ~/hadk/hybris/mw/sailfish-fpd-community
git -C ~/hadk/hybris/mw/sailfish-fpd-community checkout 5f50846
scripts/apply-patches.sh ~/hadk        # everything except sensorfw (see step 2)
```

Build (`scripts/buduj-hybris.sh` runs this in the container):

```sh
source build/envsetup.sh
lunch lineage_nx591j-userdebug
make -j6 hybris-hal libdroidmedia minimediaservice minisfservice libminisf \
    libaudioflingerglue libaudioflingerglue_32 miniafservice \
    hwcomposer.msm8952 gralloc.msm8952 copybit.msm8952 memtrack.msm8952 \
    nubia-audiobridge nubia-audiotest nubia-audiorec \
    gps.msm8952 libloc_eng libloc_core libgps.utils libbiometry_fp_api
```

| Target group | Why it is listed explicitly |
|---|---|
| `libdroidmedia`, `minimediaservice`, `minisfservice`, `libminisf` | `droidmedia` is not a make target on this base |
| `hwcomposer/gralloc/copybit/memtrack.msm8952` | the display HALs on the LineageOS `/system` are built from newer cm-14.1 sources and crash with the hybris `libbinder` |
| `libaudioflingerglue*`, `miniafservice` | CameraService waits for `media.audio_flinger` |
| `nubia-audio*` | 32-bit audio bridge and test tools |
| `gps.msm8952`, `libloc_*`, `libgps.utils` | GPS HAL with the XTRA patch |
| `libbiometry_fp_api` | fingerprint HAL wrapper for `sailfish-fpd-community` |

`external/droidmedia` needs full git history (`git fetch --unshallow --tags`) for packaging.

### 2. Sailfish OS packages (Platform SDK)

```sh
cp -r droid-hal/* $ANDROID_ROOT/rpm/                       # + git submodule dhd
cp -r droid-config/* $ANDROID_ROOT/hybris/droid-configs/   # + submodule droid-configs-device
cp -r droid-hal-version/* $ANDROID_ROOT/hybris/droid-hal-version-nx591j/
cp -r android/miniaf $ANDROID_ROOT/hybris/droid-miniaf-nx591j
cp -r extras $ANDROID_ROOT/hybris/nx591j-extras
```

Stages in this order (`scripts/pakiety-sfos.sh` runs them in the SDK container; `OFFLINE=1`
adds `-o` so local middleware patches are kept):

| # | Stage | Command (`rpm/dhd/helpers/build_packages.sh …`) | Notes |
|---|---|---|---|
| 1 | fpd | `hybris/mw/sailfish-fpd-community/rpm/copy-hal.sh`<br>`-o --build=hybris/mw/sailfish-fpd-community --spec=rpm/droid-biometry-fp.spec`<br>`-o --build=hybris/mw/sailfish-fpd-community --spec=rpm/sailfish-fpd-community.spec` | **before droid-hal**: `copy-hal.sh` moves `libbiometry_fp_api` out of `out/`, otherwise two packages ship it |
| 2 | droid-hal | `--droid-hal` | |
| 3 | miniaf | `-o --build=hybris/droid-miniaf-nx591j --spec=rpm/droid-miniaf-nx591j.spec` | droid-hal drops `miniafservice` |
| 4 | configs | `--configs` | droid-config + patterns |
| 5 | mw | `--mw`, then `scripts/apply-patches.sh $ANDROID_ROOT`, then `-o --mw` | the first run clones middleware and sensorfw fails; patch and rebuild offline |
| 6 | gg | `-o --gg` | droidmedia |
| 7 | extras | `-o --build=hybris/nx591j-extras --spec=rpm/nx591j-extras.spec` | |
| 8 | version | `-o --version` | |

### 3. Image and installation zip

| Step | Command | Notes |
|---|---|---|
| Image | `scripts/obraz-sfos.sh -nx591j3` | replaces `build_packages.sh --mic`: same kickstart plus the [Chum](https://github.com/sailfishos-chum) repo, Chum GUI and Pure Maps preinstalled, Chum kept enabled (`ssu ar`) |
| Signing | `python3 scripts/sign_ota.py <zip> <signed.zip> testkey.x509.pem testkey.pem <tmpdir>` | whole-file signature like `signapk -w`; the LineageOS recovery accepts only signed zips (AOSP test keys for unofficial builds) |
| Recovery | `scripts/recovery-sfos.sh recovery.img recovery-sfos.img` | from the LineageOS 14.1 `recovery.img` |

## Porting notes

Problems hit while bringing Sailfish OS 5.1 (aarch64) up on a hybris-14.1 / kernel 3.10
base. Many are not Nubia specific and will bite any 64-bit port on an Android 7 base.

### Kernel

| Symptom | Cause | Fix |
|---|---|---|
| `mer_verify_kernel_config` errors | missing options | enabled DEVTMPFS(+MOUNT), FHANDLE, IKCONFIG(+PROC), TMPFS_POSIX_ACL, QUOTA*, UTS/IPC/PID/NET_NS, VT, AUTOFS4, CGROUP_DEVICE/PERF, MEMCG, CHECKPOINT_RESTORE, WATCHDOG_NOWAYOUT; disabled DUMMY, ANDROID_PARANOID_NETWORK; `selinux=0 audit=0` |
| build fails with MEMCG=y | duplicate `mem_cgroup_allow_attach()` (vendor leftover) | removed |
| panic ~60 s after boot (`cleanup_net → kmem_cache_destroy → sysfs_remove_one`) | per-netns conntrack slab named `nf_conntrack_%pK`; with `kptr_restrict=2` every netns gets the same name | slab named with a counter (disabling NET_NS breaks sandboxed apps: firejail `clone: Invalid argument`) |
| panic after ~30 min of heavy I/O | `mmc_blk_cmdq_issue_rq` BUG in eMMC command queueing | `CONFIG_MMC_CQ_HCI` disabled |
| register dumps in dmesg for every process | glibc probes clone3/close_range/rseq → `do_ni_syscall` | `pr_debug` only, as in mainline |
| localsearch restarts every second, PulseAudio "Could not create memfd" | no `memfd_create` in 3.10 | backport from 3.17: atomic `i_mmap_writable`, file sealing, syscall 279 / compat 385 |
| no Bluetooth controller | WCN3680 BT runs over SMD, no `hci_smd` | `hci_smd` from CAF msm-3.10 + `setup` hook programming the BD address from `/persist/bluetooth/.bt_nv.bin` (NVM tag 2) |
| capacitive keys wrong | reported as MENU / HOME / BACK (`synaptics,cap-button-codes`) | remapped to back / home / home |

### Android init (droid-hal-init)

| Symptom | Cause | Fix |
|---|---|---|
| `Failed to initialize property area` | bionic treats failing `fsetxattr(security.selinux)` as fatal; `selinux=0` → EOPNOTSUPP | ignore EOPNOTSUPP |
| no Android services start | `init_user0` runs `vdc --wait`, waits forever for `vold` | removed |
| `nonencrypted` trigger never fires | dhd deletes `fstab.*`, `mount_all` fails | `trigger nonencrypted` after `mount_all` |
| services from LineageOS `/system/etc/init/*.rc` never start | hybris init only reads `/usr/libexec/droid-hybris/system/etc/init` | added `logd.rc` (logcat), `mediacodec.rc`, `mediaextractor.rc` (CameraService, Gecko), `miniaf.rc`, `rild.rc` (telephony) |
| USB gadget conflicts | `init.qcom.usb.rc` fights `usb_moded` | import removed |
| `ipacm` crashes every few seconds | reads `/etc/IPACM_cfg.xml`; Sailfish OS has its own `/etc` | symlink to `/system/etc` |

### Graphics

| Symptom | Cause | Fix |
|---|---|---|
| hwcomposer crashes in `Parcel::unflatten_binder` | LineageOS display HALs (newer cm-14.1) inline `Parcel`/`sp<>` code that does not match the hybris `libbinder` | build the display HALs in the hybris tree (`/usr/libexec/droid-hybris/system/lib64/hw` is searched first); `HYBRIS_NO_MEDIA` patch (no `libmedia`/`libskia`) |
| lipstick crashes in `QObject::event` / `moveToThread` once EGL loads | on aarch64, Android 7 bionic (libEGL, Adreno) writes TLS slots at tp+24…tp+56 – the start of glibc's static TLS, where Qt keeps per-thread data | `libtlspad.so` (256-byte initial-exec `__thread`) first in `/etc/ld.so.preload` |
| every app crashes in `gralloc_register_buffer` | libhybris calls `native_handle_clone()` without a prototype (not in Android 7 headers); C assumes `int` → 64-bit pointer truncated | prototype added (invisible on 32-bit ports) |
| Pure Maps (MapLibre) crashes when zooming / routing | Adreno 510 under libhybris loses vertex buffer bindings recorded in VAOs (memcpy from a buffer offset, then GPU fault @0) | `libnovao` (LD_PRELOAD) hides the VAO entry points; `QSG_RENDER_LOOP=basic`; no `customcontext` (it calls VAO functions unchecked) |

### Audio and calls

| Symptom | Cause | Fix |
|---|---|---|
| PulseAudio hangs, `ADM open timedout`, `pcm_prepare returned -1` | 64-bit audio HAL + ACDB do not work; Android 7 runs `audioserver` 32-bit | `nubia-audiobridge`: 32-bit program, PulseAudio `module-pipe-sink` → FIFO → HAL, HAL input → FIFO → `module-pipe-source`; standby after 0.5 s of silence |
| everything routed to `sink.null` | `xpolicy.conf` selects devices by properties | pipe sink gets `droid.output.primary/media_latency/low_latency=true` |
| `module-pipe-source` does not load | refuses a FIFO created by another user; several `source_properties=` break the parser | PulseAudio creates the mic FIFO; one property at load, the rest via `update-source-proplist` |
| no speaker after boot | TAS2555 firmware requested before `/system` is mounted | `droid-load-firmware.sh` waits up to 30 s (never rebind the codec at runtime: DAPM panic) |
| silence in calls | nothing sets `AUDIO_MODE_IN_CALL`; the msm8952 HAL (voice_extn) also waits for `vsid=<VOICEMMODE1/2>;call_state=2` from the dialer | control FIFO in the bridge (`call 1\|2`, `normal`, `speaker 0\|1`, `mute 0\|1`) driven by `nubia-callaudio` (ofono + voicecall UI) |
| speaker / mute toggles ignored | `audioModeChanged` carries no value, the property cannot be read as root, and the service starts before the session bus | watch the `setAudioMode` / `setMuteMicrophone` calls; retry until the session bus exists |

### Telephony

| Symptom | Cause | Fix |
|---|---|---|
| no modem in ofono | main `ril-daemon` not started (see init) and only binder RIL config (Android 8+) | `ofono-ril-plugin` + `/etc/ofono/ril_subscription.conf` (sockets `rild`, `rild2`) |
| RIL requests never answered | `sub=SUBx` makes ofono send an old qcril header that libril 7 misreads | no `sub=` |
| ofono crashes loading the config | `transport=socket` without parameters | no `transport=` |
| no modems after boot | qcril restarts once at boot (IPC router permissions race) and needs ~35 s | `startTimeout=90000` |
| mobile data cannot be enabled | dual SIM: no data SIM selected | `/etc/ofono/main.conf`: `[ModemManager] AutoSelectDataSim=once` (`auto` is ignored) |

### Connectivity, sensors, other

| Area | Symptom | Cause | Fix |
|---|---|---|---|
| Wi-Fi | no `wlan0` | built-in Pronto driver waits for a firmware path | `echo sta > /sys/module/wlan/parameters/fwpath` (`wlan-pronto-start.service`) |
| Bluetooth | `bluetoothd` status=216/GROUP | bluez5 template adds `SupplementaryGroups=uhid`, no such group on Android 7 | template drop-in removed (`delete_file.list`) |
| Bluetooth | no sound on some speakers | speakers that are also an A2DP source stream to *our* sink endpoint | `nubia-bt-a2dp-fix` connects the a2dp-sink profile |
| GPS | first fix takes minutes | HAL disables XTRA when the native XTRA client 2.0 exists – it only runs in `system_server` | HAL patch; the location service downloads XTRA (`/etc/gps_xtra.ini`); settings live in `/var/lib/location/location.conf` |
| Sensors | no battery indicator, no rotation | csd hw-settings without `[features]` → ssu-sysinfo reports only Suspend/Reboot | `[features]` (lower case, keys like `Battery`, `GSensor`, values `1`) |
| Sensors | rotation lost after boot | sensorfwd opens the sensors HAL before `sensors.qcom` creates its socket | sensorfwd waits for `/dev/socket/sensor_ctl_socket` |
| Keys | home key ignored | lipstick needs `[Keys] Keys=0x01000090,0x01000061` | numeric Qt key codes (names are not parsed) |
| Haptics | no feedback | default effects 5–30 ms too short; capacitive keys produce no ngfd events | longer effects; `nubia-keyhaptic` reads the input device |
| Fingerprint | not supported by fpd | FPC1020 HAL is API 2.0 (pre-HIDL) | legacy HAL backend for `sailfish-fpd-community` |
| Fingerprint | enrollment hangs at 100 % | FPC `post_enroll` waits for its own worker thread, fpd called it from there | finish enrollment on the daemon thread |
| Camera / video | CameraService waits forever | droid-hal drops `miniafservice`; gg skips audioflingerglue with `pulseaudio-modules-droid-hidl` | `droid-miniaf-nx591j` package |
| Middleware | build errors | sensorfw uses Android 8 `sensors.h` names; droidmedia sets `layerCount` (Android ≥ 8) | compat defines; `layerCount` only on Android ≥ 8 |
| Config | file conflict | droid-configs ships `/etc/ofono/binder.conf` like `ofono-configs-binder` | removed via `delete_file.list` |

### Recovery

| Symptom | Cause | Fix (`scripts/recovery-sfos.sh`) |
|---|---|---|
| "Failed to extract filesystem!" installing the zip | SELinux enforcing: the hybris updater gets `Permission denied` on `/data` | `androidboot.selinux=permissive` on the recovery command line |
| "failed to find /misc partition", factory reset from the OS does nothing | Android 7 `bootloader_message` looks `/misc` up in `/fstab.<ro.hardware>`, not `etc/recovery.fstab` | `/misc` added to `fstab.qcom` |

### Debugging tips

| Problem | Tip |
|---|---|
| HAL errors | with `logd.rc` in place `/system/bin/logcat` works; HAL errors only show up there |
| kernel panic | logs in pstore (`mount -t pstore pstore /mnt`, `console-ramoops-0`); after a panic the phone sits in Qualcomm download mode (`19d2:ffae`) – hold power |
| panic within a minute of boot | catch the debug telnet (`scripts/zlap-telnet.sh`) and stop services, or `touch /init_enter_debug2` |
| testing a HAL in isolation | Android executables run directly from the Sailfish shell (32-bit too), e.g. `android/nubia-audio/audiotest.cpp` |
| crash in an Android library | `gdb` + `info proc mappings` + `out/target/product/*/symbols` (mind the first `LOAD` vaddr) |
| D-Bus sessions | services that track a client (sensorfw, geoclue) drop it when the D-Bus connection closes – test with one long-lived connection, not `dbus-send` |

## Packages

| Package | Source | Contents |
|---|---|---|
| `droid-hal-nx591j` | `droid-hal/` (dhd) | Android side built in the hybris tree, `hybris-boot`, display/GPS HALs, audio bridge |
| `droid-config-nx591j` | `droid-config/` | runtime config (`sparse/`), patterns, ofono, sensorfw, PulseAudio, csd hw-settings |
| `droid-miniaf-nx591j` | `android/miniaf/` | 32-bit `miniafservice` + `libaudioflingerglue` |
| `droid-biometry-fp`, `sailfish-fpd-community` | `patches/sailfish-fpd-community/` | fingerprint HAL wrapper and daemon (legacy HAL backend) |
| `nx591j-extras` | `extras/` | `libtlspad`, key haptics, longer ngfd effects, `nubia-bt-attach`, `nubia-bt-a2dp-fix`, `nubia-callaudio`, `libnovao` + Pure Maps launcher (`%triggerin` on `harbour-pure-maps`) |

## Repository layout

| Path | Contents |
|---|---|
| `manifest/` | local manifest for the hybris-14.1 tree (device, common tree, kernel, vendor) |
| `patches/<project>/` | bionic, system/core, hybris-boot, libhybris, display-caf, droidmedia, sensorfw, sailfish-fpd-community, msm8976-common, kernel |
| `droid-hal/` | `droid-hal-nx591j.spec` (dhd as submodule) |
| `droid-config/` | `droid-config-nx591j` (spec, patterns, `sparse/` with the runtime fixes) |
| `droid-hal-version/` | `droid-hal-version-nx591j.spec` |
| `android/nubia-audio/` | 32-bit audio bridge (PulseAudio ↔ Android audio HAL) + test tools |
| `android/miniaf/` | `droid-miniaf-nx591j` spec |
| `extras/` | `nx591j-extras` spec, scripts and sources |
| `scripts/` | build container, build/package/image scripts, recovery repack, OTA signing, diagnostics |

The kernel with all Sailfish OS changes is also a separate repository
([kopebax/android_kernel_nubia_msm8976](https://github.com/kopebax/android_kernel_nubia_msm8976),
branch `sfos-hybris-14.1`); the same commits are in `patches/kernel_nubia_msm8976/`.

## Credits

| | |
|---|---|
| [HighwayStar](https://github.com/HighwayStar) | LineageOS device tree, kernel and vendor repos for the Nubia MSM8976 family |
| [mer-hybris](https://github.com/mer-hybris) / [Sailfish OS](https://github.com/sailfishos) | HADK, libhybris, droid-hal-device and middleware |
| [piggz](https://github.com/piggz) | sailfish-fpd-community |
| [Sailfish OS Chum](https://github.com/sailfishos-chum), [rinigus](https://github.com/rinigus) | Chum repository, Pure Maps |
| LineageOS | Android base |

## License

Code in this repository (audio bridge, extras, scripts, packaging) is under the
[BSD 3-Clause License](LICENSE). Files in `patches/` modify third-party projects and are
under the license of the project they apply to (Linux kernel: GPL-2.0, AOSP/LineageOS:
Apache-2.0, libhybris: Apache-2.0/LGPL, sailfish-fpd-community: its license, …). Vendor
blobs are not part of this repository.
