#!/bin/bash
source "$HOME/.config/scripts/log.sh"

if [[ -z "$1" ]]; then
    log_error "no wallpaper path given"
    exit 1
fi

if ! awww query 2>/dev/null; then
    log_info "awww daemon not running — starting it"
    awww-daemon &
    sleep 0.5
fi

if ! awww img "$1" --transition-type center --transition-fps 60; then
    log_error "awww img failed for: $1"
    exit 1
fi

# letzte Auswahl merken → autostart.lua setzt sie beim nächsten Login wieder
mkdir -p "$HOME/.cache/wallpaper-picker"
ln -sf "$(realpath "$1")" "$HOME/.cache/wallpaper-picker/current"

# Login-Hintergrund (ReGreet) – greeter-User kann ~ nicht lesen, daher Kopie
if [[ -w /var/lib/greeter-theme ]]; then
    magick "$1[0]" -resize '2560x1440>' -quality 90 /var/lib/greeter-theme/wallpaper.jpg 2>/dev/null \
        || log_warn "greeter wallpaper copy failed for: $1"
fi
