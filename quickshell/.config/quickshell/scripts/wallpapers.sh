#!/usr/bin/env bash
# Listet Wallpaper für den Launcher: "CURRENT<TAB>pfad" und je Bild "pfad<TAB>vorschaubild".
# Vorschaubilder wie früher im Rofi-Picker: ~/.cache/wallpaper-picker/<md5(pfad+mtime)>.png, 320×180
WALL_DIR="$HOME/Pictures/wallpapers"
THUMB_DIR="$HOME/.cache/wallpaper-picker"
mkdir -p "$THUMB_DIR"
printf 'CURRENT\t%s\n' "$(readlink -e "$THUMB_DIR/current" 2>/dev/null)"
find "$WALL_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) -print0 | sort -z |
while IFS= read -r -d '' img; do
    key="$(printf '%s%s' "$img" "$(stat -c %Y "$img")" | md5sum | cut -c1-16)"
    thumb="$THUMB_DIR/$key.png"
    [[ -f "$thumb" ]] || magick "$img[0]" -thumbnail 320x180^ -gravity center -extent 320x180 "$thumb" 2>/dev/null
    printf '%s\t%s\n' "$img" "$thumb"
done
