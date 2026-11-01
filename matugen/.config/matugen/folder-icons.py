#!/usr/bin/env python3
"""Färbt die Papirus-Ordner-Icons passend zur Matugen-Akzentfarbe – ohne root.

Legt ~/.local/share/icons/Papirus-Matugen an: erbt alles von Papirus-Dark und enthält nur
Symlinks für Ordner/Home-Icons, die auf die Papirus-Farbvariante zeigen, die der
Akzentfarbe am nächsten kommt (z. B. folder.svg -> /usr/share/icons/Papirus/.../folder-pink.svg).

Die Akzentfarbe kommt aus ~/.cache/matugen/folder-icons.txt (Matugen-Template),
oder als Argument: folder-icons.py <hex>
"""
import colorsys
import re
import subprocess
import sys
from pathlib import Path

PAPIRUS = Path("/usr/share/icons/Papirus")
THEME = Path.home() / ".local/share/icons/Papirus-Matugen"
ACCENT = Path.home() / ".cache/matugen/folder-icons.txt"
DEFAULT = "blue"  # Papirus verlinkt standardmäßig auf die blaue Variante

# Repräsentative Farbe je papirus-folders-Variante (Ordnerfront)
PALETTE = {
    "blue": "#5294e2", "adwaita": "#93c0ea", "breeze": "#57b8ec", "nordic": "#81a1c1",
    "indigo": "#5c6bc0", "violet": "#7e57c2", "magenta": "#ca71df", "pink": "#f06292",
    "red": "#e25252", "carmine": "#a30002", "deeporange": "#eb6637", "orange": "#ee923a",
    "paleorange": "#eeca8f", "yellow": "#f9bd30", "brown": "#ae8e6c", "palebrown": "#d1bfae",
    "green": "#87b158", "teal": "#16a085", "cyan": "#00bcd4", "darkcyan": "#45abb7",
    "bluegrey": "#607d8b", "grey": "#8e8e8e", "black": "#4f4f4f", "white": "#e4e4e4",
}


def hsv(hex_color: str) -> tuple[float, float, float]:
    h = hex_color.lstrip("#")
    return colorsys.rgb_to_hsv(*(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)))


def nearest(hex_color: str) -> str:
    h1, s1, v1 = hsv(hex_color)

    def dist(name: str) -> float:
        h2, s2, v2 = hsv(PALETTE[name])
        dh = min(abs(h1 - h2), 1 - abs(h1 - h2)) * 2  # Farbton zählt am meisten
        # Matugen-Akzente sind pastellig → Sättigung/Helligkeit nur schwach gewichten,
        # außer die Farbe ist fast grau, dann sollen die Grautöne gewinnen
        w = 0.3 if s1 > 0.15 else 2.0
        return dh * (s1 > 0.15) + w * abs(s1 - s2) + 0.3 * abs(v1 - v2)

    return min(PALETTE, key=dist)


def build(color: str) -> None:
    dirs = []
    for places in sorted(PAPIRUS.glob("*/places")):
        rel = places.relative_to(PAPIRUS)
        out = THEME / rel
        out.mkdir(parents=True, exist_ok=True)
        for old in out.iterdir():
            old.unlink()
        for link in places.iterdir():
            if not link.is_symlink():
                continue
            target = link.readlink().name
            if not re.match(rf"^(folder|user)-{DEFAULT}(-|\.)", target):
                continue
            new = places / target.replace(f"-{DEFAULT}", f"-{color}", 1)
            if new.exists():
                (out / link.name).symlink_to(new)
        dirs.append(str(rel))

    # Directories-Einträge aus Papirus übernehmen, damit Größe/Skalierung stimmen
    blocks, current = {}, None
    for line in (PAPIRUS / "index.theme").read_text().splitlines():
        if line.startswith("["):
            current = line.strip("[]")
            blocks[current] = []
        elif current and line.strip():
            blocks[current].append(line)
    sections = "".join(
        f"[{d}]\n" + "\n".join(blocks[d]) + "\n\n" for d in dirs if d in blocks
    )
    (THEME / "index.theme").write_text(
        "[Icon Theme]\n"
        "Name=Papirus-Matugen\n"
        "Comment=Papirus-Dark mit Ordnerfarbe aus Matugen (generiert)\n"
        "Inherits=Papirus-Dark,Papirus,breeze-dark,hicolor\n"
        f"Directories={','.join(dirs)}\n\n" + sections
    )


def main() -> int:
    if not PAPIRUS.is_dir():
        print("folder-icons: Papirus nicht installiert, übersprungen")
        return 0
    if len(sys.argv) > 1:
        accent = sys.argv[1]
    elif ACCENT.exists():
        accent = ACCENT.read_text().strip()
    else:
        accent = PALETTE["blue"]
    color = nearest(accent)
    build(color)

    # Theme kurz wechseln → laufende GTK-Apps laden die neuen Links
    gs = ["gsettings", "set", "org.gnome.desktop.interface", "icon-theme"]
    subprocess.run(gs + ["Papirus-Dark"], check=False)
    subprocess.run(gs + ["Papirus-Matugen"], check=False)
    print(f"folder-icons: {accent} -> {color}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
