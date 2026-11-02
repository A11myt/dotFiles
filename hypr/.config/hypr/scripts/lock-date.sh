#!/usr/bin/env bash
# Datumszeile für hyprlock: Punkt vor dem Monat in der Matugen-Akzentfarbe.
# Liest $primary aus themes/matugen.conf (Format: rgba(rrggbbaa)) → Pango braucht #rrggbb.
color=$(sed -nE 's/^\$primary = rgba\(([0-9a-fA-F]{6})[0-9a-fA-F]{2}\)$/#\1/p' \
    "$HOME/.config/hypr/themes/matugen.conf" 2>/dev/null)
date +" %A   %d <span foreground='${color:-#ffffff}'>•</span> %B %Y"
