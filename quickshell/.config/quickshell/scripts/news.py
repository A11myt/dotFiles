#!/usr/bin/env python3
"""Schlagzeilen aus RSS/Atom-Feeds für das Dashboard.

  news.py '<feeds-json>' [--refresh]
  feeds-json: [{"name": "...", "url": "..."}, ...]
Ausgabe: JSON-Liste {title, link, source, time (Unix-Zeit), error?}, neueste zuerst.
Cache 15 min in $XDG_RUNTIME_DIR (pro Feed-Liste).
"""
import hashlib
import html
import json
import os
import re
import sys
import time
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from email.utils import parsedate_to_datetime
from datetime import datetime
from pathlib import Path

CACHE_S = 15 * 60
PER_FEED = 15


def when(text: str | None) -> float:
    if not text:
        return 0.0
    text = text.strip()
    try:
        return parsedate_to_datetime(text).timestamp()          # RSS: RFC 822
    except (TypeError, ValueError):
        pass
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).timestamp()   # Atom: ISO 8601
    except ValueError:
        return 0.0


def clean(t: str | None) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", t or ""))).strip()


def local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def fetch(feed: dict) -> list[dict]:
    req = urllib.request.Request(feed["url"], headers={"User-Agent": "Mozilla/5.0 (quickshell-dashboard)"})
    with urllib.request.urlopen(req, timeout=6) as r:
        root = ET.fromstring(r.read())
    items = []
    for el in root.iter():
        kind = local(el.tag)
        if kind not in ("item", "entry"):
            continue
        f = {local(c.tag): c for c in el}
        link = f.get("link")
        href = (link.get("href") or link.text) if link is not None else ""
        # nicht mit `or` verketten: Elemente ohne Kinder gelten in Python als „falsch“
        date = next((f[k] for k in ("pubDate", "updated", "published", "date") if k in f), None)
        title = clean(f["title"].text if "title" in f else "")
        if title:
            items.append({"title": title, "link": (href or "").strip(), "source": feed["name"],
                          "time": when(date.text if date is not None else None)})
        if len(items) >= PER_FEED:
            break
    return items


def main() -> int:
    feeds = json.loads(sys.argv[1]) if len(sys.argv) > 1 else []
    key = hashlib.sha1(json.dumps(feeds, sort_keys=True).encode()).hexdigest()[:12]
    cache = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / f"qs-news-{key}.json"
    if "--refresh" not in sys.argv and cache.exists() and time.time() - cache.stat().st_mtime < CACHE_S:
        print(cache.read_text())
        return 0
    out = []
    with ThreadPoolExecutor(max_workers=8) as ex:
        for feed, res in zip(feeds, ex.map(lambda f: _safe(f), feeds)):
            out.extend(res)
    out.sort(key=lambda x: x["time"], reverse=True)
    text = json.dumps(out, ensure_ascii=False)
    # nur gute Ergebnisse cachen (sonst beim nächsten Mal erneut versuchen)
    if any("error" not in x for x in out):
        cache.write_text(text)
    print(text)
    return 0


def _safe(feed: dict) -> list[dict]:
    try:
        return fetch(feed)
    except Exception as e:  # ein kaputter Feed soll die anderen nicht stören
        return [{"title": f"Feed nicht erreichbar: {type(e).__name__}", "link": "", "source": feed.get("name", "?"),
                 "time": 0, "error": True}]


if __name__ == "__main__":
    sys.exit(main())
