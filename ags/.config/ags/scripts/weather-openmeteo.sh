#!/usr/bin/env bash
# shellcheck source=/home/jason/.config/scripts/log.sh
source "$HOME/.config/scripts/log.sh"

LAT="49.66"
LON="9.00"

CACHE="/tmp/ags-weather.json"
URL="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current_weather=true"

JSON="$(curl -fsS --connect-timeout 2 --max-time 3 "$URL" 2>/dev/null)"
RC=$?

if [[ $RC -ne 0 || -z "$JSON" ]]; then
  log_error "curl failed (exit $RC) — using cache or placeholder"
  [[ -f "$CACHE" ]] && cat "$CACHE" || echo '{"text":"?","tooltip":"weather unavailable"}'
  exit 0
fi

temp="$(echo "$JSON" | jq -r '.current_weather.temperature // empty')"
code="$(echo "$JSON" | jq -r '.current_weather.weathercode // empty')"
is_day="$(echo "$JSON" | jq -r '.current_weather.is_day // 1')"

if [[ -z "$temp" || -z "$code" ]]; then
  log_error "jq parse failed — temp='$temp' code='$code'"
  [[ -f "$CACHE" ]] && cat "$CACHE" || echo '{"text":"?","tooltip":"parse error"}'
  exit 0
fi

# WMO code -> condition key
cond="cloudy"
case "$code" in
  0) cond="sunny" ;;
  1|2|3) cond="cloudy" ;;
  45|48) cond="foggy" ;;
  51|53|55|56|57|61|63|65|66|67|80|81|82) cond="rainy" ;;
  71|73|75|77|85|86) cond="snowy" ;;
  95|96|99) cond="thunder" ;;
  *) cond="cloudy" ;;
esac

# Nerd Font icon in plain text (no special punctuation)
icon="󰖐"
case "$cond" in
  sunny)   icon="󰖙 " ;;
  cloudy)  icon="󰖐 " ;;
  rainy)   icon="󰖗 " ;;
  snowy)   icon="󰖘 " ;;
  foggy)   icon="󰖑 " ;;
  thunder) icon="󰙾 " ;;
esac

t_int="$(printf "%.0f" "$temp" 2>/dev/null || echo "?")"
daytxt="day"; [[ "$is_day" == "0" ]] && daytxt="night"

OUT="$(jq -nc \
  --arg text "${icon} ${t_int}C" \
  --arg tooltip "Open-Meteo code ${code} ${daytxt}" \
  '{text:$text, tooltip:$tooltip}')"

echo "$OUT" > "$CACHE"
cat "$CACHE"
