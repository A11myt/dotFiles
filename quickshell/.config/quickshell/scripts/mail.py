#!/usr/bin/env python3
"""Ungelesene E-Mails (IMAP) für Dashboard und Leiste.

  mail.py [<konten.json>] [--refresh]
  konten.json (~/.local/share/quickshell/mail.json):
    [{"name": "Gmail", "host": "imap.gmail.com", "user": "ich@gmail.com", "web": "https://mail.google.com"}]
Passwort im Schlüsselbund (bei Gmail ein App-Passwort):
  secret-tool store --label="Quickshell Mail ich@gmail.com" service qs-mail account ich@gmail.com
Ausgabe: JSON {accounts: [{name, unread, web, mails: [{from, subject, date}], error?}]}
Nur lesen: BODY.PEEK → Mails werden NICHT als gelesen markiert. Cache 3 min.
"""
import email.header
import email.utils
import imaplib
import json
import os
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

CACHE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "qs-mail.json"
CACHE_S = 180
SHOW = 5


def decode(v: str) -> str:
    try:
        return str(email.header.make_header(email.header.decode_header(v or ""))).strip()
    except Exception:
        return (v or "").strip()


def password(user: str) -> str:
    r = subprocess.run(["secret-tool", "lookup", "service", "qs-mail", "account", user], capture_output=True, text=True)
    return r.stdout.rstrip("\n")


def check(acc: dict) -> dict:
    out = {"name": acc.get("name") or acc["user"], "user": acc["user"], "web": acc.get("web", ""), "unread": 0, "mails": []}
    pw = password(acc["user"])
    if not pw:
        out["error"] = "kein Passwort im Schlüsselbund"
        return out
    try:
        with imaplib.IMAP4_SSL(acc.get("host", "imap.gmail.com"), int(acc.get("port", 993)), timeout=15) as m:
            m.login(acc["user"], pw)
            m.select("INBOX", readonly=True)            # nur lesen
            _, data = m.search(None, "UNSEEN")
            ids = data[0].split()
            out["unread"] = len(ids)
            for i in reversed(ids[-SHOW:]):
                _, msg = m.fetch(i, "(BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])")
                hdr = email.message_from_bytes(msg[0][1])
                name, addr = email.utils.parseaddr(decode(hdr.get("From", "")))
                try:
                    ts = int(email.utils.parsedate_to_datetime(hdr.get("Date")).timestamp())
                except Exception:
                    ts = 0
                out["mails"].append({"from": name or addr, "subject": decode(hdr.get("Subject", "")) or "(kein Betreff)", "date": ts})
    except imaplib.IMAP4.error as e:
        out["error"] = "Anmeldung fehlgeschlagen" if "auth" in str(e).lower() or "login" in str(e).lower() else "IMAP-Fehler"
    except OSError as e:
        out["error"] = "nicht erreichbar (" + type(e).__name__ + ")"
    return out


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    cfg = Path(args[0]).expanduser() if args else Path.home() / ".local/share/quickshell/mail.json"
    try:
        accounts = json.loads(cfg.read_text())
    except (OSError, ValueError):
        accounts = []
    key = json.dumps(accounts, sort_keys=True)
    if "--refresh" not in sys.argv and CACHE.exists() and time.time() - CACHE.stat().st_mtime < CACHE_S:
        d = json.loads(CACHE.read_text())
        if d.get("key") == key:
            print(json.dumps(d))
            return 0
    with ThreadPoolExecutor(max_workers=4) as ex:
        res = list(ex.map(check, accounts))
    out = {"key": key, "time": int(time.time()), "accounts": res, "unread": sum(a["unread"] for a in res)}
    CACHE.write_text(json.dumps(out))
    CACHE.chmod(0o600)
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
