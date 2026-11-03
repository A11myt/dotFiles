#!/usr/bin/env python3
"""Wallpaper von wallhaven.cc suchen und herunterladen (nur jugendfrei, ohne Anmeldung).

  wallhaven.py search "<suche>" [seite]   leer = Toplist des letzten Monats
      → JSON {items: [{id, thumb, full, res, size}], page, lastPage}
  wallhaven.py get <id> <full-url>        → lädt nach ~/Pictures/wallpapers/wallhaven-<id>.<ext>,
                                            gibt den Pfad aus (vorhanden → nicht erneut laden)
Mindestens 1920×1080, Seitenverhältnis 16:9/16:10, Kategorien Allgemein/Anime/Personen.
"""
import json
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://wallhaven.cc/api/v1/search"
DEST = Path.home() / "Pictures/wallpapers"
MAX_BYTES = 40 * 1024 * 1024
# erkennt Bilder an den ersten Bytes (nicht an Endung/Header des Servers)
MAGIC = {b"\xff\xd8\xff": ".jpg", b"\x89PNG\r\n\x1a\n": ".png", b"RIFF": ".webp"}


def get(url: str, timeout: int = 15) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "quickshell-wallpaper-picker"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        data = r.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES:
        raise ValueError("zu groß")
    return data


def search(query: str, page: int) -> int:
    params = {"categories": "111", "purity": "100", "atleast": "1920x1080", "ratios": "16x9,16x10", "page": page}
    if query.strip():
        params.update(q=query.strip(), sorting="relevance")
    else:
        params.update(sorting="toplist", topRange="1M")
    try:
        d = json.loads(get(API + "?" + urllib.parse.urlencode(params)))
    except Exception as e:
        print(json.dumps({"items": [], "error": type(e).__name__}))
        return 0
    items = [{"id": x["id"], "thumb": x["thumbs"]["small"], "full": x["path"], "res": x["resolution"],
              "size": x["file_size"]} for x in d.get("data", [])]
    print(json.dumps({"items": items, "page": d["meta"]["current_page"], "lastPage": d["meta"]["last_page"]}))
    return 0


def download(wid: str, url: str) -> int:
    if not re.fullmatch(r"[a-z0-9]{4,10}", wid) or not url.startswith("https://w.wallhaven.cc/full/"):
        print("ungültige Angabe", file=sys.stderr)
        return 2
    DEST.mkdir(parents=True, exist_ok=True)
    for f in DEST.glob(f"wallhaven-{wid}.*"):      # schon da
        print(f)
        return 0
    data = get(url, timeout=60)
    ext = next((e for m, e in MAGIC.items() if data.startswith(m)), None)
    if not ext or (ext == ".webp" and data[8:12] != b"WEBP"):
        print("kein Bild", file=sys.stderr)
        return 1
    out = DEST / f"wallhaven-{wid}{ext}"
    tmp = out.with_suffix(".part")
    tmp.write_bytes(data)
    tmp.rename(out)
    print(out)
    return 0


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "search":
        sys.exit(search(sys.argv[2] if len(sys.argv) > 2 else "", int(sys.argv[3]) if len(sys.argv) > 3 else 1))
    if cmd == "get" and len(sys.argv) == 4:
        sys.exit(download(sys.argv[2], sys.argv[3]))
    print(__doc__.strip(), file=sys.stderr)
    sys.exit(2)
