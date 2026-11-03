#!/usr/bin/env python3
"""wintheme – Matugen für Windows 11: Farben aus dem Wallpaper für Windows, Windows Terminal und VS Code.

  wintheme [bild]               Bild als Wallpaper setzen und alles einfärben
                                (ohne Bild: aktuelles Windows-Wallpaper nur einfärben)
  wintheme --mode light|dark    Hell/Dunkel (wird gemerkt)
  wintheme --scheme NAME        tonal-spot, vibrant, expressive, fidelity, content,
                                fruit-salad, rainbow, neutral, monochrome (wird gemerkt)
  wintheme --color 1-4|auto     Ausgangsfarbe für dieses Bild (wird pro Bild gemerkt)
  wintheme --sources [bild]     die 4 Ausgangsfarben eines Bildes anzeigen
  wintheme --watch              im Hintergrund: bei jedem Wallpaper-Wechsel neu einfärben
  wintheme --dry-run            nur anzeigen, nichts ändern
  wintheme --only windows,terminal,vscode   nur Teile anwenden

Farbberechnung wie Matugen (Material You, Spezifikation 2021, Quantisierung auf 112 px):
gleiches Bild + gleiche Einstellungen → gleiche Farben wie auf dem Linux-Laptop.
Einstellungen: %APPDATA%\\wintheme\\config.json
"""
import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

from PIL import Image
from materialyoucolor.dynamiccolor.dynamic_color import DynamicColor
from materialyoucolor.dynamiccolor.material_dynamic_colors import MaterialDynamicColors
from materialyoucolor.hct import Hct
from materialyoucolor.quantize import QuantizeCelebi
from materialyoucolor.score.score import Score

IS_WIN = sys.platform == "win32"
HERE = Path(__file__).resolve().parent
APPDATA = Path(os.environ.get("APPDATA", Path.home() / ".config"))
LOCALAPPDATA = Path(os.environ.get("LOCALAPPDATA", Path.home() / ".local/share"))
CONFIG = APPDATA / "wintheme" / "config.json"
DEFAULTS = {"mode": "dark", "scheme": "tonal-spot", "contrast": 0.0, "pick": {}, "titlebars": False}

SCHEMES = {
    "tonal-spot": "scheme_tonal_spot.SchemeTonalSpot", "vibrant": "scheme_vibrant.SchemeVibrant",
    "expressive": "scheme_expressive.SchemeExpressive", "fidelity": "scheme_fidelity.SchemeFidelity",
    "content": "scheme_content.SchemeContent", "fruit-salad": "scheme_fruit_salad.SchemeFruitSalad",
    "rainbow": "scheme_rainbow.SchemeRainbow", "neutral": "scheme_neutral.SchemeNeutral",
    "monochrome": "scheme_monochrome.SchemeMonochrome",
}
# Windows-Akzentpalette: 8 Stufen (hell3 … Akzent … dunkel3, letzte unbenutzt) als Tonwerte
ACCENT_TONES = [90, 77, 62, 50, 42, 28, 14, 60]


# ── Einstellungen ────────────────────────────────────────────────────────────
def load_config() -> dict:
    try:
        return {**DEFAULTS, **json.loads(CONFIG.read_text(encoding="utf-8"))}
    except (OSError, ValueError):
        return dict(DEFAULTS)


def save_config(cfg: dict) -> None:
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    CONFIG.write_text(json.dumps(cfg, indent=2, ensure_ascii=False), encoding="utf-8")


# ── Farben ───────────────────────────────────────────────────────────────────
def hexc(argb: int) -> str:
    return "#%06x" % (argb & 0xFFFFFF)


def source_colors(image: Path) -> list[int]:
    img = Image.open(image).convert("RGBA").resize((112, 112), Image.Resampling.BILINEAR)
    pixels = list(img.get_flattened_data()) if hasattr(img, "get_flattened_data") else list(img.getdata())
    return Score.score(QuantizeCelebi(pixels, 128))[:4]


def scheme_class(name: str):
    mod, cls = SCHEMES[name].split(".")
    module = __import__(f"materialyoucolor.scheme.{mod}", fromlist=[cls])
    return getattr(module, cls)


def snake(name: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()


def palette(image: Path, cfg: dict) -> dict:
    sources = source_colors(image)
    pick = cfg["pick"].get(image.name)
    src = sources[min(int(pick), len(sources) - 1)] if isinstance(pick, int) else sources[0]
    dark = cfg["mode"] != "light"
    s = scheme_class(cfg["scheme"])(Hct.from_int(src), dark, float(cfg["contrast"]), spec_version="2021")
    colors = {}
    for n in dir(MaterialDynamicColors):
        dc = getattr(MaterialDynamicColors, n)
        if n.startswith("_") or not isinstance(dc, DynamicColor):
            continue
        try:
            colors[snake(n)] = hexc(dc.get_argb(s))
        except Exception:          # Rollen, die es nur in der 2025-Spezifikation gibt
            pass
    return {"colors": colors, "dark": dark, "sources": [hexc(c) for c in sources], "source": hexc(src),
            "accent": [hexc(s.primary_palette.tone(t)) for t in ACCENT_TONES[:7]] + [hexc(s.tertiary_palette.tone(60))]}


# ── Windows (Registry) ───────────────────────────────────────────────────────
def rgb(h: str) -> tuple[int, int, int]:
    return int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)


def abgr(h: str, a: int = 0xFF) -> int:
    r, g, b = rgb(h)
    return (a << 24) | (b << 16) | (g << 8) | r


def current_wallpaper() -> Path | None:
    if not IS_WIN:
        return None
    import winreg
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Control Panel\Desktop") as k:
        p = winreg.QueryValueEx(k, "WallPaper")[0]
    if p and Path(p).is_file():
        return Path(p)
    t = APPDATA / "Microsoft/Windows/Themes/TranscodedWallpaper"   # z. B. bei Diashow/Spotlight
    return t if t.is_file() else None


def apply_windows(pal: dict, image: Path | None, set_wall: bool, titlebars: bool, dry: bool) -> str:
    acc = pal["accent"]
    if dry or not IS_WIN:
        return f"Windows: Akzent {acc[3]}, {'dunkel' if pal['dark'] else 'hell'}" + (" (nur Vorschau)" if dry else " (nicht Windows – übersprungen)")
    import ctypes
    import winreg
    HK = winreg.HKEY_CURRENT_USER

    def put(path, name, kind, value):
        with winreg.CreateKeyEx(HK, path, 0, winreg.KEY_SET_VALUE) as k:
            winreg.SetValueEx(k, name, 0, kind, value)

    if set_wall and image:
        ctypes.windll.user32.SystemParametersInfoW(20, 0, str(image), 3)   # SPI_SETDESKWALLPAPER, speichern + melden
    palette_bytes = b"".join(bytes([*rgb(c), 0]) for c in acc)
    explorer = r"Software\Microsoft\Windows\CurrentVersion\Explorer\Accent"
    put(explorer, "AccentPalette", winreg.REG_BINARY, palette_bytes)
    put(explorer, "AccentColorMenu", winreg.REG_DWORD, abgr(acc[3]))
    put(explorer, "StartColorMenu", winreg.REG_DWORD, abgr(acc[5]))
    dwm = r"Software\Microsoft\Windows\DWM"
    put(dwm, "AccentColor", winreg.REG_DWORD, abgr(acc[3]))
    r, g, b = rgb(acc[3])
    put(dwm, "ColorizationColor", winreg.REG_DWORD, (0xC4 << 24) | (r << 16) | (g << 8) | b)
    put(dwm, "ColorizationAfterglow", winreg.REG_DWORD, (0xC4 << 24) | (r << 16) | (g << 8) | b)
    put(dwm, "ColorPrevalence", winreg.REG_DWORD, 1 if titlebars else 0)
    light = 0 if pal["dark"] else 1
    themes = r"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    put(themes, "AppsUseLightTheme", winreg.REG_DWORD, light)
    put(themes, "SystemUsesLightTheme", winreg.REG_DWORD, light)
    put(r"Control Panel\Desktop", "AutoColorization", winreg.REG_DWORD, 0)   # Windows soll nicht selbst wählen
    # allen Fenstern Bescheid geben (Taskleiste, Startmenü, Apps übernehmen es live)
    res = ctypes.c_ulong()
    for area in ("ImmersiveColorSet", "WindowsThemeElement"):
        ctypes.windll.user32.SendMessageTimeoutW(0xFFFF, 0x001A, 0, area, 0x0002, 3000, ctypes.byref(res))
    return f"Windows: Akzent {acc[3]}, {'dunkel' if pal['dark'] else 'hell'}"


# ── JSON mit Kommentaren (Windows Terminal, VS Code) ─────────────────────────
def strip_jsonc(text: str) -> str:
    """Entfernt // und /* */ außerhalb von Strings sowie Kommas vor } oder ]."""
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1]); i += 2; continue
            if c == '"':
                in_str = False
        elif c == '"':
            in_str = True; out.append(c)
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
            continue
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        else:
            out.append(c)
        i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


# ── Windows Terminal ─────────────────────────────────────────────────────────
def terminal_settings() -> list[Path]:
    pk = LOCALAPPDATA / "Packages"
    cands = [pk / "Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json",
             pk / "Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json",
             LOCALAPPDATA / "Microsoft/Windows Terminal/settings.json"]
    return [p for p in cands if p.is_file()]


def terminal_scheme(c: dict) -> dict:
    # wie die Alacritty-Vorlage auf dem Laptop
    return {
        "name": "Matugen",
        "background": c["background"], "foreground": c["on_surface"],
        "cursorColor": c["on_surface_variant"], "selectionBackground": c["primary"],
        "black": "#181818", "red": c["error"], "green": c["primary"], "yellow": c["inverse_primary"],
        "blue": c["primary"], "purple": c["tertiary"], "cyan": c["secondary"], "white": "#BAC2DE",
        "brightBlack": "#585B70", "brightRed": "#F38BA8", "brightGreen": "#A6E3A1", "brightYellow": "#F9E2AF",
        "brightBlue": "#89B4FA", "brightPurple": "#F5C2E7", "brightCyan": "#94E2D5", "brightWhite": "#A6ADC8",
    }


def apply_terminal(pal: dict, dry: bool) -> str:
    files = terminal_settings()
    if not files:
        return "Windows Terminal: nicht gefunden – übersprungen"
    scheme = terminal_scheme(pal["colors"])
    for f in files:
        raw = f.read_text(encoding="utf-8-sig")
        data = json.loads(strip_jsonc(raw))
        data["schemes"] = [s for s in data.get("schemes", []) if s.get("name") != "Matugen"] + [scheme]
        data.setdefault("profiles", {})
        if isinstance(data["profiles"], list):           # sehr alte Form
            data["profiles"] = {"list": data["profiles"]}
        data["profiles"].setdefault("defaults", {})["colorScheme"] = "Matugen"
        if dry:
            continue
        backup = f.with_name(f.name + ".wintheme-backup")
        if not backup.exists():
            backup.write_text(raw, encoding="utf-8")
        tmp = f.with_name(f.name + ".tmp")
        tmp.write_text(json.dumps(data, indent=4, ensure_ascii=False), encoding="utf-8")
        os.replace(tmp, f)                                 # Terminal lädt Änderungen sofort
    return f"Windows Terminal: Schema „Matugen“ ({len(files)} Datei{'en' if len(files) > 1 else ''})" + (" (nur Vorschau)" if dry else "")


# ── VS Code ──────────────────────────────────────────────────────────────────
BEGIN = "  // >>> wintheme (generiert – wird beim nächsten Einfärben ersetzt)"
END = "  // <<< wintheme"


def render(template: str, colors: dict) -> str:
    def sub(m):
        return colors.get(m.group(1), m.group(0))
    return re.sub(r"\{\{\s*colors\.([a-z_]+)\.default\.hex\s*\}\}", sub, template)


def apply_vscode(pal: dict, dry: bool) -> str:
    files = [APPDATA / d / "User/settings.json" for d in ("Code", "Code - Insiders", "VSCodium")]
    files = [f for f in files if f.is_file()]
    if not files:
        return "VS Code: nicht gefunden – übersprungen"
    colors = json.loads(render((HERE / "templates/vscode-colors.json").read_text(encoding="utf-8"), pal["colors"]))
    for f in files:
        text = f.read_text(encoding="utf-8-sig")
        theme = re.search(r'"workbench\.colorTheme"\s*:\s*"([^"]+)"', text)
        value = {f"[{theme.group(1)}]": colors} if theme else colors
        body = json.dumps(value, indent=2).replace("\n", "\n  ")
        block = f'{BEGIN}\n  "workbench.colorCustomizations": {body},\n{END}'
        pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.S)
        text = pattern.sub(lambda _: block, text) if pattern.search(text) else text.replace("{", "{\n" + block, 1)
        if not dry:
            f.write_text(text, encoding="utf-8")
    return f"VS Code: Farben gesetzt ({len(files)}×)" + (" (nur Vorschau)" if dry else "")


# ── Ablauf ───────────────────────────────────────────────────────────────────
def run(image: Path, cfg: dict, set_wall: bool, only: set[str], dry: bool) -> None:
    pal = palette(image, cfg)
    print(f"{image.name}: Ausgangsfarbe {pal['source']} · {cfg['scheme']} · {'dunkel' if pal['dark'] else 'hell'}")
    if "windows" in only:
        print("  " + apply_windows(pal, image, set_wall, cfg["titlebars"], dry))
    if "terminal" in only:
        print("  " + apply_terminal(pal, dry))
    if "vscode" in only:
        print("  " + apply_vscode(pal, dry))


def watch(cfg_only: set[str]) -> None:
    """Wallpaper-Wechsel in Windows erkennen und neu einfärben (für den Autostart, pythonw)."""
    last = None
    while True:
        try:
            p = current_wallpaper()
            key = (str(p), p.stat().st_mtime) if p else None
            if key and key != last:
                if last is not None:
                    run(p, load_config(), False, cfg_only, False)
                last = key
        except Exception as e:     # nie abstürzen, nächster Versuch in 5 s
            print("wintheme --watch:", e, file=sys.stderr)
        time.sleep(5)


def main() -> int:
    ap = argparse.ArgumentParser(prog="wintheme", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("image", nargs="?", help="Bild (sonst aktuelles Wallpaper)")
    ap.add_argument("--mode", choices=["dark", "light"])
    ap.add_argument("--scheme", choices=list(SCHEMES))
    ap.add_argument("--color", help="1–4 oder auto (Ausgangsfarbe für dieses Bild)")
    ap.add_argument("--contrast", type=float, help="-1 … 1")
    ap.add_argument("--titlebars", choices=["on", "off"], help="Akzentfarbe in Titelleisten")
    ap.add_argument("--only", default="windows,terminal,vscode")
    ap.add_argument("--sources", action="store_true")
    ap.add_argument("--watch", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    cfg = load_config()
    changed = False
    for k in ("mode", "scheme", "contrast"):
        if getattr(a, k) is not None:
            cfg[k] = getattr(a, k); changed = True
    if a.titlebars:
        cfg["titlebars"] = a.titlebars == "on"; changed = True
    only = {x.strip() for x in a.only.split(",") if x.strip()}

    if a.watch:
        if changed:
            save_config(cfg)
        watch(only)
        return 0

    image = Path(a.image).expanduser().resolve() if a.image else current_wallpaper()
    if not image or not image.is_file():
        print("wintheme: kein Bild angegeben und kein Windows-Wallpaper gefunden", file=sys.stderr)
        return 1
    if a.sources:
        for i, c in enumerate(source_colors(image), 1):
            print(f"  {i}: {hexc(c)}")
        return 0
    if a.color:
        if a.color == "auto":
            cfg["pick"].pop(image.name, None)
        else:
            cfg["pick"][image.name] = max(1, min(4, int(a.color))) - 1
        changed = True
    if changed and not a.dry_run:
        save_config(cfg)
    run(image, cfg, set_wall=bool(a.image), only=only, dry=a.dry_run)
    return 0


if __name__ == "__main__":
    sys.exit(main())
