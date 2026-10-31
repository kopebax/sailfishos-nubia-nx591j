#!/usr/bin/env bash
# Pakiety RPM portu Sailfish OS (nx591j) w kontenerze sfossdk; logi pkg-<etap>.log
# Użycie: pakiety-sfos.sh [etapy...]   (domyślnie: fpd droid-hal miniaf configs mw gg extras version)
#   fpd    – droid-biometry-fp (libbiometry_fp_api z drzewa Androida) + sailfish-fpd-community
#   miniaf – droid-miniaf-nx591j (android/miniaf -> $ANDROID_ROOT/hybris/droid-miniaf-nx591j)
#   extras – nx591j-extras (katalog extras/ skopiowany do $ANDROID_ROOT/hybris/nx591j-extras)
# OFFLINE=1 – bez "git pull" w repozytoriach middleware (zachowuje lokalne poprawki)
etapy=${*:-fpd droid-hal miniaf configs mw gg extras version}
opt=; [ -n "$OFFLINE" ] && opt=-o
bp="rpm/dhd/helpers/build_packages.sh $opt"
for etap in $etapy; do
    case $etap in
        fpd) cmd="hybris/mw/sailfish-fpd-community/rpm/copy-hal.sh &&
                  $bp --build=hybris/mw/sailfish-fpd-community --spec=rpm/droid-biometry-fp.spec &&
                  $bp --build=hybris/mw/sailfish-fpd-community --spec=rpm/sailfish-fpd-community.spec" ;;
        miniaf) cmd="$bp --build=hybris/droid-miniaf-nx591j --spec=rpm/droid-miniaf-nx591j.spec" ;;
        extras) cmd="$bp --build=hybris/nx591j-extras --spec=rpm/nx591j-extras.spec" ;;
        *) cmd="$bp --$etap" ;;
    esac
    echo "== $(date +%T) $etap $opt"
    docker exec -u builder -w /home/builder/hadk sfossdk bash -lc "source ~/.hadk.env; $cmd" \
        > /home/alexy/android/budowa/pkg-$etap.log 2>&1
    rc=$?; echo "== $(date +%T) $etap exit $rc"; tail -4 /home/alexy/android/budowa/pkg-$etap.log | cut -c1-200
    [ $rc -eq 0 ] || exit $rc
done
