#!/usr/bin/env bash
# Vorlagen aus der Matugen-Config des Laptops nach wintheme kopieren (gleiche Farbzuordnung unter Windows)
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
cp "$here/../../matugen/.config/matugen/templates/vscode-colors.json" "$here/templates/"
echo "templates/vscode-colors.json aktualisiert"
