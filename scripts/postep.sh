#!/usr/bin/env bash
# Podgląd budowy LineageOS na żywo: postęp ninja, ETA, CPU, ostatnie linie logu.
# Użycie: ./postep.sh [log] [liczba_linii_logu]   (wyjście: Ctrl+C)
L=${1:-/home/alexy/android/budowa/budowa.log}
N=${2:-15}
OKNO=600            # ETA liczone z tempa z ostatnich 10 minut
R=/sys/class/powercap/intel-rapl:0

declare -a T K      # próbki: czas, liczba wykonanych kroków
start=$(stat -c %W "$L" 2>/dev/null); [[ $start == 0 || -z $start ]] && start=$(stat -c %Y "$L")
e_prev=$(cat $R/energy_uj 2>/dev/null); t_prev=$(date +%s)

hms() { local s=$1; printf '%d:%02d:%02d' $((s/3600)) $((s%3600/60)) $((s%60)); }

trap 'tput cnorm; exit' INT TERM
tput civis
while true; do
    teraz=$(date +%s)
    ost=$(grep -aoE '^\[ *[0-9]+% [0-9]+/[0-9]+\]' "$L" | tail -1)
    read -r pr done total < <(sed -E 's/\[ *([0-9]+)% ([0-9]+)\/([0-9]+)\]/\1 \2 \3/' <<<"$ost")
    done=${done:-0}; total=${total:-0}

    T+=("$teraz"); K+=("$done")
    while (( ${#T[@]} > 1 && teraz - T[0] > OKNO )); do T=("${T[@]:1}"); K=("${K[@]:1}"); done
    dt=$(( teraz - T[0] )); dk=$(( done - K[0] ))
    (( dt < 120 )) && { dt=$(( teraz - start )); dk=$done; }   # za mało próbek - średnia od początku budowy
    if (( dk > 0 && total > done )); then eta=$(( (total - done) * dt / dk )); eta_txt="$(hms $eta) (ok. $(date -d @$((teraz+eta)) +%H:%M))"
    elif (( total > 0 && done >= total )); then eta_txt="koniec"
    else eta_txt="liczę…"; fi
    tempo=$(( dt > 0 ? dk * 60 / dt : 0 ))

    e=$(cat $R/energy_uj 2>/dev/null); moc=$(( (e - e_prev) / ((teraz - t_prev) > 0 ? (teraz - t_prev) * 1000000 : 1) )); e_prev=$e; t_prev=$teraz
    mhz=$(awk '/MHz/{s+=$4;n++} END{printf "%.0f", s/n}' /proc/cpuinfo)
    temp=$(sensors 2>/dev/null | awk '/Package id 0/{print $4}')
    prof=$(powerprofilesctl get 2>/dev/null)

    kol=$(tput cols); szer=$(( kol - 10 )); (( szer < 10 )) && szer=10
    pelne=$(( total > 0 ? done * szer / total : 0 ))
    pasek=$(printf '%*s' "$pelne" '' | tr ' ' '#')$(printf '%*s' $((szer - pelne)) '' | tr ' ' '.')

    if pgrep -f 'make -j6 bacon' >/dev/null; then stan="BUDUJE"
    elif grep -aqE 'make: \*\*\*|ninja: build stopped' "$L"; then stan="BŁĄD"
    elif grep -aq 'Package Complete' "$L"; then stan="GOTOWE"
    else stan="nie działa"; fi

    {
        tput cup 0 0
        printf 'Budowa LineageOS 14.1 nx591j  [%s]   %s\e[K\n' "$stan" "$(date +%T)"
        printf '[%s] %3s%%\e[K\n' "$pasek" "${pr:-0}"
        printf 'Kroki: %s / %s   tempo: %s/min   czas: %s   ETA: %s\e[K\n' "$done" "$total" "$tempo" "$(hms $((teraz - start)))" "$eta_txt"
        printf 'CPU: %s MHz  %s W  %s  profil: %s\e[K\n' "$mhz" "$moc" "$temp" "$prof"
        printf '%*s\e[K\n' "$kol" '' | tr ' ' '-'
        tail -n "$N" "$L" | tr -d '\r' | cut -c1-"$kol" | sed 's/$/\x1b[K/'
        tput ed
    }
    [[ $stan == BUDUJE ]] || { [[ $stan != "nie działa" ]] && grep -aE 'FAILED:|error:|Package Complete' "$L" | tail -3 | cut -c1-"$kol"; }
    sleep 5
done
