#!/usr/bin/env python3
"""Liest ~/.config/hypr/keybinds.lua und gibt die Tastenkürzel als JSON aus (für die Übersicht).

Abschnitte:   -- ── Name ──
Beschreibung: Kommentar hinter hl.bind(...)
Sonderfälle:  -- @ TASTEN | Beschreibung   (z. B. für Schleifen)
"""
import json
import re
from pathlib import Path

SRC = Path.home() / ".config/hypr/keybinds.lua"
NAMES = {
    "SUPER": "Super", "SHIFT": "Shift", "CTRL": "Strg", "ALT": "Alt", "grave": "`", "TAB": "Tab",
    "slash": "/", "left": "←", "right": "→", "up": "↑", "down": "↓", "Print": "Druck",
    "Insert": "Einfg", "DELETE": "Entf", "mouse_down": "Mausrad ↓", "mouse_up": "Mausrad ↑",
    "mouse:272": "linke Maustaste", "mouse:273": "rechte Maustaste",
    "XF86AudioRaiseVolume": "Lauter-Taste", "XF86AudioLowerVolume": "Leiser-Taste",
    "XF86AudioMute": "Stumm-Taste", "XF86AudioMicMute": "Mikro-Taste",
    "XF86MonBrightnessUp": "Helligkeit +", "XF86MonBrightnessDown": "Helligkeit −",
    "XF86AudioNext": "⏭", "XF86AudioPrev": "⏮", "XF86AudioPlay": "⏯", "XF86AudioPause": "⏸",
}


def keys(spec: str) -> list[str]:
    return [NAMES.get(k, k.upper() if len(k) == 1 else k) for k in (p.strip() for p in spec.split("+")) if k]


def main() -> None:
    text = SRC.read_text()
    variables = dict(re.findall(r'^local\s+(\w+)\s*=\s*"([^"]*)"', text, re.M))
    section, out, seen = "Allgemein", [], set()
    for line in text.splitlines():
        st = line.strip()
        if m := re.match(r"--\s*──\s*(.+?)\s*──", st):
            section = m.group(1)
            continue
        if m := re.search(r"--\s*@\s*(.+?)\s*\|\s*(.+)$", st):
            spec, desc = m.groups()
        elif st.startswith("hl.bind(") and (m := re.search(r"\)\s+--\s*(.+)$", st)):
            desc = m.group(1)
            first = st[len("hl.bind("):].split(",", 1)[0]
            # mainMod .. " + Q"  →  SUPER + Q
            spec = "".join(variables.get(t.strip(), t.strip().strip('"')) for t in first.split(".."))
        else:
            continue
        k = tuple(keys(spec))
        if (k, desc) in seen:
            continue
        seen.add((k, desc))
        out.append({"section": section, "keys": list(k), "desc": desc})
    print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
