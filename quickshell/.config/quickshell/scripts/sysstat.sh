#!/usr/bin/env bash
# Momentaufnahme für die Info-Leiste (alle paar Sekunden): Zeilen "schlüssel werte…"
read -r _ u n s i w q sq st _ < /proc/stat
echo "cpu $((u + n + s + q + sq + st)) $((i + w))"
awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} /^SwapTotal:/{st=$2} /^SwapFree:/{sf=$2} END{print "mem", t, a, st, sf}' /proc/meminfo
awk 'NR>2 && $1 !~ /^lo:/ {gsub(":", " "); rx+=$2; tx+=$10} END{print "net", rx, tx}' /proc/net/dev
for h in /sys/class/hwmon/hwmon*; do
    [[ $(cat "$h/name" 2>/dev/null) == coretemp ]] && { echo "temp $(cat "$h/temp1_input")"; break; }
done
read -r up _ < /proc/uptime; echo "uptime ${up%.*}"
