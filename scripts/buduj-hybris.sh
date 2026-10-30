#!/usr/bin/env bash
# Budowa hybris-hal + droidmedia (Sailfish OS, baza hybris-14.1) dla nx591j. Log: hybris.log
docker run --rm -v /home/alexy/android/los14:/src -v /home/alexy/android/ccache:/ccache los14-build bash -c '
set -e
sed -i "s/^\(jdk.tls.disabledAlgorithms=\)SSLv3, TLSv1, TLSv1.1,/\1SSLv3,/" /etc/java-8-openjdk/security/java.security
export LC_ALL=C USE_CCACHE=1 CCACHE_DIR=/ccache CCACHE_EXEC=/usr/bin/ccache
export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx4g"
cd /src
source build/envsetup.sh
lunch lineage_nx591j-userdebug
# hybris-hal + elementy, które dhd pakuje do /usr/libexec/droid-hybris (patrz „Building” w README.md)
make -j6 hybris-hal libdroidmedia minimediaservice minisfservice libminisf \
    libaudioflingerglue libaudioflingerglue_32 miniafservice \
    hwcomposer.msm8952 gralloc.msm8952 copybit.msm8952 memtrack.msm8952 \
    nubia-audiobridge nubia-audiotest nubia-audiorec
ls -la out/target/product/nx591j/hybris-*.img
'
