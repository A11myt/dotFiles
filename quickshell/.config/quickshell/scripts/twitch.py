#!/usr/bin/env python3
"""Wer ist live auf Twitch? Für das Dashboard.

  twitch.py '<["kanal1", "kanal2"]>' [--refresh]
Ausgabe: JSON {channels: [{login, live, title, game, viewers, since}], source, error?}

Offizielle Twitch-API (Helix), wenn im Schlüsselbund hinterlegt:
  secret-tool store --label="Quickshell Twitch Client-ID" service qs-twitch key client_id
  secret-tool store --label="Quickshell Twitch Secret"    service qs-twitch key client_secret
(App anlegen: dev.twitch.tv/console/apps → „Register Your Application“, OAuth-Redirect
http://localhost, Kategorie „Application Integration“, Typ „Confidential“.)
Sonst decapi.me (inoffiziell, ohne Anmeldung, langsamer): nur Live-Status, Titel/Spiel
für Kanäle, die live sind. Ergebnis 3 min im Cache.
"""
import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

CACHE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "qs-twitch.json"
TOKEN = Path.home() / ".cache/quickshell/twitch-token.json"
CACHE_S = 180


def secret(key: str) -> str:
    r = subprocess.run(["secret-tool", "lookup", "service", "qs-twitch", "key", key], capture_output=True, text=True)
    return r.stdout.strip()


def get(url: str, headers: dict | None = None, data: bytes | None = None, timeout: int = 8) -> str:
    req = urllib.request.Request(url, data=data, headers={"User-Agent": "quickshell-dashboard", **(headers or {})})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode()


def helix(channels: list[str], cid: str, csec: str) -> list[dict]:
    tok = None
    if TOKEN.exists():
        t = json.loads(TOKEN.read_text())
        if t.get("expires", 0) > time.time() + 60:
            tok = t["token"]
    if not tok:
        body = urllib.parse.urlencode({"client_id": cid, "client_secret": csec, "grant_type": "client_credentials"}).encode()
        t = json.loads(get("https://id.twitch.tv/oauth2/token", data=body))
        tok = t["access_token"]
        TOKEN.parent.mkdir(parents=True, exist_ok=True)
        TOKEN.write_text(json.dumps({"token": tok, "expires": time.time() + t["expires_in"]}))
        TOKEN.chmod(0o600)
    q = "&".join("user_login=" + urllib.parse.quote(c) for c in channels[:100])
    live = json.loads(get("https://api.twitch.tv/helix/streams?" + q, {"Client-Id": cid, "Authorization": "Bearer " + tok}))["data"]
    by = {s["user_login"].lower(): s for s in live}
    out = []
    for c in channels:
        s = by.get(c.lower())
        out.append({"login": c, "live": bool(s), "title": s["title"] if s else "", "game": s["game_name"] if s else "",
                    "viewers": s["viewer_count"] if s else 0, "since": s["started_at"] if s else ""})
    return out


def decapi(channels: list[str]) -> list[dict]:
    def one(c):
        try:
            up = get("https://decapi.me/twitch/uptime/" + urllib.parse.quote(c), timeout=10).strip()
        except Exception:
            return {"login": c, "live": False, "title": "", "game": "", "viewers": 0, "since": "", "unknown": True}
        live = "offline" not in up.lower() and "error" not in up.lower()
        d = {"login": c, "live": live, "title": "", "game": "", "viewers": 0, "since": up if live else ""}
        if live:   # Titel/Spiel nur für Live-Kanäle (schont das Limit)
            for k in ("title", "game"):
                try:
                    d[k] = get(f"https://decapi.me/twitch/{k}/" + urllib.parse.quote(c), timeout=10).strip()
                except Exception:
                    pass
        return d
    with ThreadPoolExecutor(max_workers=4) as ex:
        return list(ex.map(one, channels))


def main() -> int:
    channels = [c.strip().lower() for c in json.loads(sys.argv[1] if len(sys.argv) > 1 else "[]") if c.strip()]
    key = ",".join(channels)
    if "--refresh" not in sys.argv and CACHE.exists() and time.time() - CACHE.stat().st_mtime < CACHE_S:
        d = json.loads(CACHE.read_text())
        if d.get("key") == key:
            print(json.dumps(d))
            return 0
    out = {"key": key, "channels": [], "source": ""}
    cid, csec = secret("client_id"), secret("client_secret")
    try:
        if cid and csec:
            out["channels"], out["source"] = helix(channels, cid, csec), "helix"
        else:
            out["channels"], out["source"] = decapi(channels), "decapi"
    except Exception as e:
        out["error"] = type(e).__name__
    out["channels"].sort(key=lambda c: (not c["live"], -c["viewers"], c["login"]))
    if "error" not in out:
        CACHE.write_text(json.dumps(out))
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
