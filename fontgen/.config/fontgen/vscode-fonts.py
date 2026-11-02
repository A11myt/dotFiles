#!/usr/bin/env python3
"""Schreibt die fontgen-Schriften in die VS-Code-settings.json (Markerblock, JSONC bleibt erhalten).

Gleiche Schlüssel außerhalb des Blocks werden entfernt – bei doppelten Schlüsseln gewinnt in
JSON der letzte, der Block steht oben und würde sonst überschrieben.
"""
import json
import re
from pathlib import Path

VALUES = Path.home() / ".cache/fontgen/vscode.json"
SETTINGS = Path.home() / ".config/Code/User/settings.json"
BEGIN = "  // >>> fontgen (generiert von ~/.config/fontgen/vscode-fonts.py)"
END = "  // <<< fontgen"

if SETTINGS.exists():
    values = json.loads(VALUES.read_text())
    text = SETTINGS.read_text()
    block_re = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n?", re.S)
    text = block_re.sub("", text)
    for key in values:
        # einzeilige Einträge "key": wert, (inkl. optionalem Kommentar) entfernen
        text = re.sub(rf'(?m)^[ \t]*"{re.escape(key)}"\s*:.*,?[ \t]*(//.*)?\n', "", text)
    body = "\n".join(f"  {json.dumps(k)}: {json.dumps(v)}," for k, v in values.items())
    text = text.replace("{", "{\n" + f"{BEGIN}\n{body}\n{END}", 1)
    SETTINGS.write_text(text)
