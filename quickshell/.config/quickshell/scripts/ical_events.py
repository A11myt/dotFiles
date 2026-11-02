#!/usr/bin/env python3
"""Termine aus iCal-Kalendern (Google „Privatadresse im iCal-Format“, Nextcloud, …).

  calendar.py <kalender.json> [--refresh]
  kalender.json: [{"name": "...", "url": "https://…/basic.ics" oder Dateipfad}, ...]
Ausgabe: JSON {events: [{title, start, end, allDay, location, cal}], errors: [...]}
(Unix-Zeit, Zeitraum: 5 Wochen zurück bis 10 Wochen voraus, sortiert).
Die Kalenderdateien werden 15 min in ~/.cache/quickshell/ics/ gehalten (bei Netzfehler
wird die letzte gute Kopie genutzt). Die Adressen sind geheim → nie in die Dotfiles.
"""
import hashlib
import json
import re
import subprocess
import sys
import time
import urllib.request
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

from dateutil.rrule import rrulestr

CACHE = Path.home() / ".cache/quickshell/ics"
CACHE_S = 15 * 60
LOCAL = datetime.now().astimezone().tzinfo


def fetch(url: str, refresh: bool) -> str:
    if not url.startswith(("http://", "https://", "webcal://")):
        return Path(url).expanduser().read_text(errors="replace")
    url = re.sub(r"^webcal://", "https://", url)
    CACHE.mkdir(parents=True, exist_ok=True)
    f = CACHE / (hashlib.sha1(url.encode()).hexdigest()[:16] + ".ics")
    if not refresh and f.exists() and time.time() - f.stat().st_mtime < CACHE_S:
        return f.read_text(errors="replace")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "quickshell-calendar"})
        with urllib.request.urlopen(req, timeout=10) as r:
            text = r.read().decode("utf-8", errors="replace")
        f.write_text(text)
        f.chmod(0o600)
        return text
    except Exception:
        if f.exists():
            return f.read_text(errors="replace")   # letzte gute Kopie
        raise


def unfold(text: str) -> list[str]:
    out: list[str] = []
    for line in text.replace("\r\n", "\n").split("\n"):
        if line[:1] in (" ", "\t") and out:
            out[-1] += line[1:]
        elif line:
            out.append(line)
    return out


def prop(line: str) -> tuple[str, dict, str]:
    """'DTSTART;TZID=Europe/Berlin:2026…' → ('DTSTART', {'TZID': …}, '2026…')"""
    head, _, value = line.partition(":")
    name, *params = head.split(";")
    return name.upper(), dict(p.split("=", 1) for p in params if "=" in p), value


def text(v: str) -> str:
    return v.replace("\\n", "\n").replace("\\N", "\n").replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\").strip()


def zone(tzid: str | None):
    if not tzid:
        return LOCAL
    try:
        return ZoneInfo(tzid.strip('"'))
    except Exception:
        return LOCAL      # z. B. Windows-Namen aus Outlook


def when(value: str, params: dict) -> tuple[datetime, bool]:
    """→ (zeitzonenbehaftete Zeit, ganztägig?)"""
    v = value.strip()
    if params.get("VALUE") == "DATE" or re.fullmatch(r"\d{8}", v):
        d = date(int(v[:4]), int(v[4:6]), int(v[6:8]))
        return datetime(d.year, d.month, d.day, tzinfo=LOCAL), True
    dt = datetime.strptime(v.rstrip("Z")[:15], "%Y%m%dT%H%M%S")
    if v.endswith("Z"):
        return dt.replace(tzinfo=timezone.utc), False
    return dt.replace(tzinfo=zone(params.get("TZID"))), False


def duration(v: str) -> timedelta:
    m = re.fullmatch(r"([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?", v.strip())
    if not m:
        return timedelta(hours=1)
    sign, w, d, h, mi, s = m.groups()
    td = timedelta(weeks=int(w or 0), days=int(d or 0), hours=int(h or 0), minutes=int(mi or 0), seconds=int(s or 0))
    return -td if sign == "-" else td


def fix_until(rule: str, start: datetime) -> str:
    """dateutil verlangt UNTIL in UTC, wenn DTSTART eine Zeitzone hat."""
    def conv(m):
        u = m.group(1)
        if len(u) == 8:
            u_dt = datetime(int(u[:4]), int(u[4:6]), int(u[6:8]), 23, 59, 59, tzinfo=start.tzinfo)
        elif u.endswith("Z"):
            return m.group(0)
        else:
            u_dt = datetime.strptime(u[:15], "%Y%m%dT%H%M%S").replace(tzinfo=start.tzinfo)
        return "UNTIL=" + u_dt.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return re.sub(r"UNTIL=([0-9TZ]+)", conv, rule)


def events(ics: str, cal: str, lo: datetime, hi: datetime) -> list[dict]:
    raw, cur = [], None
    for line in unfold(ics):
        if line == "BEGIN:VEVENT":
            cur = []
        elif line == "END:VEVENT" and cur is not None:
            raw.append(cur)
            cur = None
        elif cur is not None:
            cur.append(prop(line))

    singles, overrides, out = [], {}, []
    for props in raw:
        ev = {"exdates": set()}
        for name, params, value in props:
            if name == "DTSTART":
                ev["start"], ev["allDay"] = when(value, params)
            elif name == "DTEND":
                ev["end"], _ = when(value, params)
            elif name == "DURATION":
                ev["dur"] = duration(value)
            elif name == "SUMMARY":
                ev["title"] = text(value)
            elif name == "LOCATION":
                ev["location"] = text(value)
            elif name == "RRULE":
                ev["rrule"] = value
            elif name == "EXDATE":
                for v in value.split(","):
                    ev["exdates"].add(when(v, params)[0].astimezone(timezone.utc).replace(second=0))
            elif name == "RECURRENCE-ID":
                ev["recid"] = when(value, params)[0].astimezone(timezone.utc).replace(second=0)
            elif name == "UID":
                ev["uid"] = value
            elif name == "STATUS":
                ev["cancelled"] = value.upper() == "CANCELLED"
        if "start" not in ev:
            continue
        if "end" not in ev:
            ev["end"] = ev["start"] + ev.get("dur", timedelta(days=1) if ev["allDay"] else timedelta(hours=1))
        if "recid" in ev:
            overrides[(ev.get("uid"), ev["recid"])] = ev
        else:
            singles.append(ev)

    def emit(ev, start):
        if ev.get("cancelled"):
            return
        end = start + (ev["end"] - ev["start"])
        if end < lo or start > hi:
            return
        out.append({"title": ev.get("title", "(ohne Titel)"), "start": int(start.timestamp()), "end": int(end.timestamp()),
                    "allDay": ev["allDay"], "location": ev.get("location", ""), "cal": cal})

    for ev in singles:
        if "rrule" not in ev:
            emit(ev, ev["start"])
            continue
        try:
            rule = rrulestr(fix_until(ev["rrule"], ev["start"]), dtstart=ev["start"])
            starts = rule.between(lo - (ev["end"] - ev["start"]), hi, inc=True)
        except (ValueError, TypeError):
            emit(ev, ev["start"])
            continue
        for s in starts:
            key = s.astimezone(timezone.utc).replace(second=0)
            if key in ev["exdates"]:
                continue
            ov = overrides.pop((ev.get("uid"), key), None)
            if ov:
                emit(ov, ov["start"])
            else:
                emit(ev, s)
    for ov in overrides.values():          # verschobene Termine ohne passende Serie im Zeitraum
        emit(ov, ov["start"])
    return out


def main() -> int:
    cfg_path = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else Path.home() / ".local/share/quickshell/calendars.json"
    try:
        cals = json.loads(cfg_path.read_text())
    except (OSError, ValueError):
        cals = []
    now = datetime.now().astimezone()
    lo, hi = now - timedelta(days=35), now + timedelta(days=70)
    result, errors = [], []
    for c in cals:
        try:
            result += events(fetch(c["url"], "--refresh" in sys.argv), c.get("name", "Kalender"), lo, hi)
        except Exception as e:
            errors.append({"cal": c.get("name", "?"), "error": type(e).__name__})
    # eigene Termine aus Obsidian (scripts/termin.py, Ordner „Termine“ im Vault)
    try:
        r = subprocess.run([sys.executable, "-I", str(Path(__file__).with_name("termin.py")), "list"],
                           capture_output=True, text=True, timeout=10)
        lo_t, hi_t = lo.timestamp(), hi.timestamp()
        result += [e for e in json.loads(r.stdout or "[]") if e["end"] >= lo_t and e["start"] <= hi_t]
    except (subprocess.TimeoutExpired, ValueError) as e:
        errors.append({"cal": "Obsidian", "error": type(e).__name__})
    result.sort(key=lambda e: (e["start"], not e["allDay"]))
    print(json.dumps({"events": result, "errors": errors, "time": int(time.time())}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
