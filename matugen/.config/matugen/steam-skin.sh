#!/usr/bin/env bash
# Steam-Skin (AdwSteamGtk) verzögert und still im Hintergrund anwenden.
# Dauert ~7–18 s und ist erst beim nächsten Steam-Start sichtbar → blockiert den Farbwechsel nicht.
# Entprellt: bei mehreren Wechseln kurz hintereinander läuft nur der letzte.
DELAY="${1:-60}"
TOKEN_FILE="$HOME/.cache/matugen/steam-skin.token"
mkdir -p "${TOKEN_FILE%/*}"
token="$(date +%s%N)"
echo "$token" > "$TOKEN_FILE"

setsid -f bash -c '
    sleep "$1"
    [[ "$(cat "$2" 2>/dev/null)" == "$3" ]] || exit 0
    flatpak run io.github.Foldex.AdwSteamGtk -i
' _ "$DELAY" "$TOKEN_FILE" "$token" </dev/null >/dev/null 2>&1
