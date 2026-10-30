#!/usr/bin/env bash
# Pakiety RPM portu Sailfish OS (nx591j) w kontenerze sfossdk; logi pkg-<etap>.log
# Użycie: pakiety-sfos.sh [etapy...]   (domyślnie: configs mw gg version)
# OFFLINE=1 – bez "git pull" w repozytoriach middleware (zachowuje lokalne poprawki)
etapy=${*:-configs mw gg version}
opt=; [ -n "$OFFLINE" ] && opt=-o
for etap in $etapy; do
    echo "== $(date +%T) --$etap $opt"
    docker exec -u builder -w /home/builder/hadk sfossdk bash -lc "source ~/.hadk.env; rpm/dhd/helpers/build_packages.sh $opt --$etap" \
        > /home/alexy/android/budowa/pkg-$etap.log 2>&1
    rc=$?; echo "== $(date +%T) --$etap exit $rc"; tail -4 /home/alexy/android/budowa/pkg-$etap.log | cut -c1-200
    [ $rc -eq 0 ] || exit $rc
done
