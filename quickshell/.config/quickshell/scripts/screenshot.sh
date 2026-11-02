#!/usr/bin/env bash
# Screenshot fertigstellen (aufgerufen von Screenshot.qml):
#   screenshot.sh <vollbild.png> <x> <y> <b> <h> <bearbeiten 0|1>
# Koordinaten in Pixeln des Vollbilds. Speichert nach ~/Pictures/Screenshots/,
# kopiert in die Zwischenablage, Benachrichtigung mit Öffnen/Bearbeiten/Ordner.
set -euo pipefail
mkdir -p "$HOME/.logs"; exec 2>>"$HOME/.logs/screenshot.log"
full=$1 x=$2 y=$3 w=$4 h=$5 edit=${6:-0}

dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
mkdir -p "$dir"
out="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

magick "$full" -crop "${w}x${h}+${x}+${y}" +repage -define png:compression-level=3 "$out"
rm -f "$full"

edit_shot() { satty --filename "$out" --output-filename "$out" --copy-command wl-copy; }

if [[ $edit == 1 ]] && command -v satty >/dev/null; then
    edit_shot
    exit 0
fi

wl-copy --type image/png < "$out"

actions=(-A default=Öffnen -A open=Öffnen)
command -v satty >/dev/null && actions+=(-A edit=Bearbeiten)
actions+=(-A folder=Ordner)

# wartet auf einen Klick → abgekoppelt, damit Quickshell nicht wartet
(
    act=$(notify-send -a Screenshot -i "$out" "${actions[@]}" \
        "Screenshot gespeichert" "In die Zwischenablage kopiert · ${w} × ${h}" 2>/dev/null) || true
    case $act in
        default|open) xdg-open "$out" ;;
        edit) edit_shot ;;
        folder) nautilus --select "$out" ;;
    esac
) </dev/null >/dev/null 2>&1 &
disown
