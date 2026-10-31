#!/usr/bin/env bash
# Obraz instalacyjny Sailfish OS (nx591j) w kontenerze sfossdk, z repozytorium Chum
# oraz preinstalowanym Chum GUI i Pure Maps. Jak build_packages.sh --mic, ale z własnym
# kickstartem. Log: /home/alexy/android/budowa/obraz.log
# Użycie: obraz-sfos.sh [EXTRA_NAME]   (domyślnie -nx591j1)
EXTRA_NAME=${1:--nx591j1}
docker exec -u builder -w /home/builder/hadk -e EXTRA_NAME="$EXTRA_NAME" sfossdk bash -lc '
set -e
source ~/.hadk.env
: "${RELEASE:=5.1.0.11}"
RELEASEMAJORMINOR=$(echo "$RELEASE" | cut -d . -f 1,2)
LOCAL_REPO=$ANDROID_ROOT/droid-local-repo/$DEVICE
mkdir -p $LOCAL_REPO/repo
createrepo_c --outputdir=$LOCAL_REPO/repo --location-prefix=../ $LOCAL_REPO

src=$ANDROID_ROOT/hybris/droid-configs/installroot/usr/share/kickstarts/Jolla-@RELEASE@-$DEVICE-@ARCH@.ks
ks=$ANDROID_ROOT/Jolla-@RELEASE@-$DEVICE-@ARCH@-chum.ks
chum="https://repo.sailfishos.org/obs/sailfishos:/chum/@RELEASEMAJORMINOR@_@ARCH@/"

# adaptation from the local repo (as build_packages.sh does for community ports),
# Chum for the image build, Chum GUI + Pure Maps in %packages
sed -e "/^repo --name=adaptation-community-common-$DEVICE-@RELEASE@/i repo --name=adaptation-community-$DEVICE-@RELEASE@ --baseurl=file://$LOCAL_REPO/repo" \
    -e "/^repo --name=jolla-@RELEASE@ /a repo --name=sailfishos-chum-@RELEASE@ --baseurl=$chum" \
    -e "/^patterns-sailfish-device-configuration-$DEVICE\$/a sailfishos-chum-gui\nharbour-pure-maps" \
    -e "/store-repository.jolla.com/d" \
    "$src" > "$ks"
# keep Chum enabled on the installed system (ssu repo, like "ssu ar" by hand)
cat >> "$ks" <<EOF

%post --erroronfail
ssu ar sailfishos-chum "$chum"
%end
EOF
grep -nE "^repo|chum|pure-maps" "$ks"

imgname=SailfishOScommunity-release-$RELEASE-$DEVICE$EXTRA_NAME
tokenmap="ARCH:$PORT_ARCH,RELEASE:$RELEASE,RELEASEMAJORMINOR:$RELEASEMAJORMINOR,RELEASEMAJOR:${RELEASE%%.*},EXTRA_NAME:$EXTRA_NAME"
sudo rm -rf "$imgname"
sudo mic create fs --arch=$PORT_ARCH \
    --tokenmap=$tokenmap \
    --record-pkgs=name,url \
    --outdir=$imgname \
    --pack-to=sfe-$DEVICE-$RELEASE$EXTRA_NAME.tar.bz2 \
    "$ks"
ls -la "$imgname"
' > /home/alexy/android/budowa/obraz.log 2>&1
rc=$?
tail -5 /home/alexy/android/budowa/obraz.log
exit $rc
