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
