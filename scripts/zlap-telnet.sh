#!/usr/bin/env bash
# Złap telnet 2323 w oknie między startem Sailfisha a awarią, zablokuj usługi Androida, pobierz pstore.
OUT=${1:-/home/alexy/android/budowa/crash-$(date +%H%M%S)}; IF=enp0s20f0u2; mkdir -p "$OUT"
echo "$(date +%T) czekam na telnet 2323 (maks. 5 min)"
for _ in $(seq 1000); do
    ip addr add 192.168.2.1/24 dev $IF 2>/dev/null
    timeout 0.5 bash -c "</dev/tcp/192.168.2.15/2323" 2>/dev/null && break
    sleep 0.3
done
timeout 0.5 bash -c "</dev/tcp/192.168.2.15/2323" 2>/dev/null || { echo "!! brak telnetu"; exit 1; }
echo "$(date +%T) telnet – blokuję usługi Androida"
{ sleep 0.3; printf "${BLOKADA:-ln -sf /dev/null /etc/systemd/user/lipstick.service; pkill -9 lipstick; sync; cat /proc/uptime; echo ZABLOKOWANE}\n"; sleep 4; printf 'exit\n'; } \
    | timeout 10 nc 192.168.2.15 2323 2>&1 | tr -d '\r' | grep -E 'ZABLOKOWANE|^[0-9]+\.[0-9]+ '
for f in console-ramoops-0 dmesg-ramoops-0 dmesg-ramoops-1 dmesg-ramoops-2; do
    { sleep 0.3
      printf "mkdir -p /tmp/ps; mountpoint -q /tmp/ps || mount -t pstore pstore /tmp/ps; [ -f /tmp/ps/$f ] && python3 -c \"import socket; s=socket.create_server(('192.168.2.15',9001)); c,_=s.accept(); c.sendfile(open('/tmp/ps/$f','rb')); c.close()\" &\n"
      sleep 1.5; printf 'exit\n'; } | timeout 5 nc 192.168.2.15 2323 >/dev/null 2>&1
    sleep 0.3; timeout 8 nc 192.168.2.15 9001 > "$OUT/$f" 2>/dev/null; [ -s "$OUT/$f" ] || rm -f "$OUT/$f"
done
ls -la "$OUT"; echo "$(date +%T) stan USB: $(lsusb | grep -oE '(18d1|19d2):[0-9a-f]{4}')"
