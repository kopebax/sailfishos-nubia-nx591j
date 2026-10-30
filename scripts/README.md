# Scripts

Helpers used during the port. Paths (`/home/alexy/android/...`, scratch dirs) reflect the
original build machine – adjust them before use.

| Script | Purpose |
|---|---|
| `Dockerfile.android-build` | Ubuntu 18.04 + OpenJDK 8 + git-lfs container for the Android tree |
| `apply-patches.sh` | apply `patches/` and copy `android/nubia-audio` into a synced tree |
| `buduj-los14.sh` | build LineageOS 14.1 (base ROM) |
| `buduj-hybris.sh` | build hybris-hal + all extra modules packaged by droid-hal |
| `pakiety-sfos.sh` | run `build_packages.sh` stages in the Platform SDK container (`OFFLINE=1` keeps local patches) |
| `postep.sh` | live progress / ETA of a running Android build |
| `sign_ota.py` | whole-file sign an update zip (signapk -w format) for the LineageOS recovery |
| `recovery-diag.sh` | catch fastboot, RAM-boot hybris-recovery, pull pstore logs |
| `zlap-telnet.sh` | catch the debug telnet right after boot (before an early crash), run a command, pull pstore |
