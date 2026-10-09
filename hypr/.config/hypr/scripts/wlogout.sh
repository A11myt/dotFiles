#!/usr/bin/env bash
source "$HOME/.config/scripts/log.sh"

top_margin_1080=400
bottom_margin_1080=400

if pgrep -x "wlogout" > /dev/null; then
  pkill -x "wlogout"
  exit 0
fi

resolution=$(hyprctl -j monitors | jq -r '.[] | select(.focused==true) | .height / .scale' | awk -F'.' '{print $1}')
hypr_scale=$(hyprctl -j monitors | jq -r '.[] | select(.focused==true) | .scale')

if [[ -z "$resolution" || -z "$hypr_scale" ]]; then
    log_error "could not detect monitor resolution/scale (hyprctl or jq failed)"
    exit 1
fi

wlogout -C "$HOME/.config/wlogout/style.css" \
        -l "$HOME/.config/wlogout/layout" \
        --protocol layer-shell \
        -b 5 \
        -T "$(awk "BEGIN {printf \"%.0f\", $top_margin_1080 * 1080 * $hypr_scale / $resolution}")" \
        -B "$(awk "BEGIN {printf \"%.0f\", $bottom_margin_1080 * 1080 * $hypr_scale / $resolution}")" &
