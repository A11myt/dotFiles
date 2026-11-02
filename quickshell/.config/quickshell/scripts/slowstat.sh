#!/usr/bin/env bash
# Seltener (alle 10–30 s): Top-Prozesse, Speicherplatz, Akkus – als JSON
# Last der letzten 0,5 s (ps zeigt nur den Schnitt über die ganze Laufzeit); gleiche Namen zusammenfassen
procs=$(top -b -n 2 -d 0.5 -w 200 | awk '
    /^top -/ { n++ } n == 2 && f { cpu[$12] += $9; mem[$12] += $6 } n == 2 && /^ *PID/ { f = 1 }
    END { for (c in cpu) if (c != "top") printf "%s %.1f %d\n", c, cpu[c], mem[c] / 1024 }' |
    sort -k2 -nr | head -5 | awk '{printf "%s{\"name\":\"%s\",\"cpu\":%s,\"mem\":%d}", (NR>1?",":""), $1, $2, $3}')
disk=$(df -B1 --output=size,used / | awk 'NR==2{printf "{\"size\":%s,\"used\":%s}", $1, $2}')
bats=""
for b in /sys/class/power_supply/BAT*; do
    [[ -d $b ]] || continue
    r() { cat "$b/$1" 2>/dev/null || echo 0; }
    bats+="${bats:+,}{\"name\":\"$(basename "$b")\",\"cap\":$(r capacity),\"status\":\"$(r status)\",\"full\":$(r energy_full),\"design\":$(r energy_full_design),\"now\":$(r energy_now),\"power\":$(r power_now),\"cycles\":$(r cycle_count),\"start\":$(r charge_control_start_threshold),\"end\":$(r charge_control_end_threshold)}"
done
printf '{"procs":[%s],"disk":%s,"bats":[%s]}\n' "$procs" "$disk" "$bats"
