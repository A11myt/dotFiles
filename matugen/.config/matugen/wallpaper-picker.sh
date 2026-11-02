#!/usr/bin/env bash
# Rofi-Wallpaper-Picker mit Vorschaubildern → wallthemes (gecachtes Matugen-Theme + awww)
source "$HOME/.config/scripts/log.sh"

WALL_DIR="$HOME/Pictures/wallpapers"
THUMB_DIR="$HOME/.cache/wallpaper-picker"
THEME="$HOME/.config/rofi/wallpaper.rasi"

# Toggle: zweiter Druck schließt den Picker
if pgrep -x rofi >/dev/null; then
    pkill -x rofi
    exit 0
fi

mkdir -p "$THUMB_DIR"

entries=""
while IFS= read -r -d '' img; do
    name="$(basename "${img%.*}")"
    # Cache-Key aus Pfad + mtime → Thumbnail wird bei geänderter Datei neu erzeugt
    key="$(printf '%s%s' "$img" "$(stat -c %Y "$img")" | md5sum | cut -c1-16)"
    thumb="$THUMB_DIR/$key.png"
    if [[ ! -f "$thumb" ]]; then
        magick "$img[0]" -thumbnail 320x180^ -gravity center -extent 320x180 "$thumb" 2>/dev/null \
            || log_warn "thumbnail failed: $img"
    fi
    entries+="$name\0icon\x1f$thumb\x1finfo\x1f$img\n"
done < <(find "$WALL_DIR" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) \
            -print0 | sort -z)

if [[ -z "$entries" ]]; then
    log_error "no wallpapers found in $WALL_DIR"
    exit 1
fi

# -format i → Index der Auswahl, damit Namen mit Sonderzeichen egal sind
idx="$(printf '%b' "$entries" | rofi -dmenu -i -show-icons -p "wallpaper" -theme "$THEME" -format i)" || exit 0

img="$(find "$WALL_DIR" -maxdepth 1 -type f \
         \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) \
         -print0 | sort -z | tr '\0' '\n' | sed -n "$((idx + 1))p")"

if [[ -z "$img" ]]; then
    log_error "selection index $idx did not resolve to a file"
    exit 1
fi

log_info "selected: $img"
# voller Pfad: Hyprland-Prozesse haben ~/.local/bin nicht zwingend im PATH
"$HOME/.local/bin/wallthemes" "$img" || log_error "wallthemes failed for: $img"
