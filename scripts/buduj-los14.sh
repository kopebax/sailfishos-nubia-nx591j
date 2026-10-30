#!/usr/bin/env bash
# Budowa LineageOS 14.1 dla nx591j w kontenerze los14-build. Log: budowa.log
docker run --rm -v /home/alexy/android/los14:/src -v /home/alexy/android/ccache:/ccache los14-build bash -c '
set -e
# Jack (Android 7) potrzebuje TLSv1, wyłączonego w nowszych OpenJDK 8
sed -i "s/^\(jdk.tls.disabledAlgorithms=\)SSLv3, TLSv1, TLSv1.1,/\1SSLv3,/" /etc/java-8-openjdk/security/java.security
export LC_ALL=C USE_CCACHE=1 CCACHE_DIR=/ccache CCACHE_EXEC=/usr/bin/ccache
export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx4g"
ccache -M 15G >/dev/null
cd /src
source build/envsetup.sh
lunch lineage_nx591j-userdebug
make -j6 bacon
ls -la out/target/product/nx591j/*.zip out/target/product/nx591j/*.img
'
