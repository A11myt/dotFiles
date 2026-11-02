#!/usr/bin/env bash
# Wettervorhersage für die Info-Leiste (Open-Meteo, Standort aus weather.sh), 30 min Cache
dir=$(dirname "$0")
eval "$(grep -E '^(LAT|LON)=' "$dir/weather.sh")"
CACHE="${XDG_RUNTIME_DIR:-/tmp}/qs-forecast.json"
if [[ -s $CACHE && -n $(find "$CACHE" -mmin -30 2>/dev/null) ]]; then cat "$CACHE"; exit 0; fi
URL="https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&timezone=auto&forecast_days=6\
&current=temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m,relative_humidity_2m\
&hourly=temperature_2m,weather_code,precipitation_probability,is_day\
&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
if json=$(curl -fsS --connect-timeout 3 --max-time 6 "$URL"); then
    printf '%s\n' "$json" > "$CACHE"; printf '%s\n' "$json"
elif [[ -s $CACHE ]]; then cat "$CACHE"
else echo '{}'; fi
