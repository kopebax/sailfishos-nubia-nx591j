#!/usr/bin/env bash
# Złap fastboot, uruchom hybris-recovery (tylko RAM), pobierz logi pstore z poprzedniej awarii.
# Kończy się od razu przy nieoczekiwanym stanie telefonu; maks. 3 min czekania na fastboot.
OUT=${1:-/home/alexy/android/budowa/crash-$(date +%H%M%S)}
IMG=/home/alexy/android/sfos/userdata-img/hybris-recovery.img
IF=enp0s20f0u2
mkdir -p "$OUT"

stan() {
    # 18d1:d001 to zarówno fastboot, jak i initramfs hybris-boot (ten ma RNDIS) – rozstrzyga fastboot devices
    if lsusb -d 18d1:d001 >/dev/null; then
        if timeout 2 fastboot devices 2>/dev/null | grep -q fastboot; then echo fastboot
        elif ip link show $IF >/dev/null 2>&1; then echo system
        else echo brak; fi
    elif lsusb -d 19d2:ffae >/dev/null; then echo awaria
    elif lsusb -d 18d1:0a02 >/dev/null; then echo system
    else echo brak; fi
}

# 1. czekaj na fastboot (maks. 180 s); "awaria" na starcie jest normalna (telefon jeszcze nie zresetowany)
# reset = telefon wyszedł z trybu awaryjnego (użytkownik przytrzymał przyciski); dopiero po nim
# start systemu oznacza nieudane wejście w fastboot
poprzedni=$(stan); echo "$(date +%T) start: $poprzedni"; reset=
for _ in $(seq 600); do
    s=$(stan)
    [ "$s" != "$poprzedni" ] && echo "$(date +%T) stan: $s"
    [ "$poprzedni" = awaria ] && [ "$s" != awaria ] && reset=1
    case $s in
        fastboot) break ;;
        system) [ -n "$reset" ] && { echo "!! Telefon uruchomił system zamiast fastboot – przytrzymaj zasilanie + ciszej"; exit 2; } ;;
    esac
    poprzedni=$s; sleep 0.3
done
[ "$(stan)" = fastboot ] || { echo "!! Brak fastboot po 3 min"; exit 1; }

# 2. odblokuj na tę sesję i uruchom recovery z RAM; bootloader Nubii sam startuje system po ~30 s
#    bez poleceń, a polecenie wysłane zaraz po enumeracji USB potrafi zawisnąć – stąd timeouty
for _ in $(seq 20); do timeout 2 fastboot devices 2>/dev/null | grep -q fastboot && break; sleep 0.3; done
ok=
for _ in 1 2 3 4 5; do
    timeout 10 fastboot oem nubia_unlock NUBIA_NX591J >/dev/null 2>&1 &&
        timeout 10 fastboot oem device-info 2>&1 | grep -q 'Nubia device unlocked: true' && { ok=1; break; }
    sleep 1
done
[ -n "$ok" ] || { echo "!! Nie udało się odblokować w tej sesji fastboot"; exit 5; }
timeout 30 fastboot boot "$IMG" 2>&1 | tail -1

# 3. czekaj na telnet (maks. 90 s)
for _ in $(seq 180); do
    ip addr add 192.168.2.1/24 dev $IF 2>/dev/null
    timeout 1 bash -c "</dev/tcp/192.168.2.15/2323" 2>/dev/null && break
    [ "$(stan)" = awaria ] && { echo "!! Awaria w trakcie startu recovery"; exit 3; }
    sleep 0.5
done
timeout 1 bash -c "</dev/tcp/192.168.2.15/2323" 2>/dev/null || { echo "!! Brak telnetu po 90 s"; exit 4; }
echo "$(date +%T) telnet gotowy"

# 4. pobierz pliki pstore (telefon wysyła, laptop odbiera – zapora laptopa blokuje ruch odwrotny)
for f in console-ramoops-0 dmesg-ramoops-0 dmesg-ramoops-1 dmesg-ramoops-2; do
    { sleep 0.5
      printf "mkdir -p /tmp/ps; mountpoint -q /tmp/ps || mount -t pstore pstore /tmp/ps; [ -f /tmp/ps/$f ] && python3 -c \"import socket; s=socket.create_server(('192.168.2.15',9001)); c,_=s.accept(); c.sendfile(open('/tmp/ps/$f','rb')); c.close()\" &\n"
      sleep 2; printf 'exit\n'; } | timeout 6 nc 192.168.2.15 2323 >/dev/null 2>&1
    sleep 0.5
    timeout 10 nc 192.168.2.15 9001 > "$OUT/$f" 2>/dev/null
    [ -s "$OUT/$f" ] || rm -f "$OUT/$f"
done
ls -la "$OUT"
