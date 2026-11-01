#!/usr/bin/env python3
"""Schreibt die Matugen-Farben als workbench.colorCustomizations in die VS-Code-settings.json.

settings.json ist JSONC (Kommentare erlaubt), deshalb kein json.load/dump auf die ganze Datei:
nur der Block zwischen den Markern wird ersetzt, alles andere bleibt unangetastet.
Die Farben gelten nur für das aktive Theme ("[<colorTheme>]"), Theme-Wechsel bleiben sauber.
"""
import json
import re
import sys
from pathlib import Path

COLORS = Path.home() / ".cache/matugen/vscode-colors.json"
SETTINGS = Path.home() / ".config/Code/User/settings.json"
BEGIN = "  // >>> matugen (generiert von ~/.config/matugen/vscode-theme.py)"
END = "  // <<< matugen"


def main() -> int:
    if not SETTINGS.exists():
        print(f"vscode: {SETTINGS} fehlt, übersprungen")
        return 0

    colors = json.loads(COLORS.read_text())
    text = SETTINGS.read_text()

    theme = re.search(r'"workbench\.colorTheme"\s*:\s*"([^"]+)"', text)
    scope = f"[{theme.group(1)}]" if theme else None
    value = {scope: colors} if scope else colors

    body = json.dumps(value, indent=2).replace("\n", "\n  ")
    block = f'{BEGIN}\n  "workbench.colorCustomizations": {body},\n{END}'

    pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.S)
    if pattern.search(text):
        text = pattern.sub(lambda _: block, text)
    else:
        # erster Lauf: direkt hinter die öffnende Klammer
        text = text.replace("{", "{\n" + block, 1)

    SETTINGS.write_text(text)
    print(f"vscode: Farben für {scope or 'alle Themes'} gesetzt")
    return 0


if __name__ == "__main__":
    sys.exit(main())
