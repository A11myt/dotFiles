#!/usr/bin/env python3
"""Termine als Notizen im Obsidian-Vault (Ordner „Termine“), kompatibel mit dem
Obsidian-Plugin „Full Calendar“ (Frontmatter title/date/startTime/endTime/allDay).

  termin.py add '<json>'   {"title", "date": "YYYY-MM-DD", "start": "HH:MM", "end": "HH:MM",
                            "allDay": bool, "location", "note"} → gibt den Pfad aus
  termin.py delete <pfad>  Termin-Notiz löschen (nur innerhalb des Termine-Ordners)
  termin.py list           alle Termine als JSON (für calendar.py)

Vault: $OBSIDIAN_VAULT oder ~/Obsidian.
"""
import json
import os
import re
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

VAULT = Path(os.environ.get("OBSIDIAN_VAULT", Path.home() / "Obsidian"))
FOLDER = VAULT / "Termine"


def safe_name(title: str) -> str:
    return re.sub(r'[\\/:*?"<>|#^\[\]]', "", title).strip()[:80] or "Termin"


def yaml_str(v: str) -> str:
    return json.dumps(v, ensure_ascii=False)          # JSON-Strings sind gültiges YAML


def add(data: dict) -> int:
    title = data["title"].strip()
    d = date.fromisoformat(data["date"])
    all_day = bool(data.get("allDay")) or not data.get("start")
    lines = ["---", f"title: {yaml_str(title)}", f"date: {d.isoformat()}", f"allDay: {'true' if all_day else 'false'}"]
    if not all_day:
        start = data["start"]
        end = data.get("end") or (datetime.strptime(start, "%H:%M") + timedelta(hours=1)).strftime("%H:%M")
        lines += [f"startTime: {yaml_str(start)}", f"endTime: {yaml_str(end)}"]
    if all_day and data.get("endDate") and data["endDate"] != d.isoformat():
        lines.append(f"endDate: {date.fromisoformat(data['endDate']).isoformat()}")   # letzter Tag (inklusive)
    if data.get("location"):
        lines.append(f"location: {yaml_str(data['location'].strip())}")
    lines += ["type: single", "tags: termin", "---", ""]
    if data.get("note"):
        lines += [data["note"].strip(), ""]
    FOLDER.mkdir(parents=True, exist_ok=True)
    # gleicher Termin schon vorhanden (Titel, Datum, Beginn)? → nicht doppelt anlegen
    for f in FOLDER.glob(f"{d.isoformat()} *.md"):
        fm = frontmatter(f.read_text(errors="replace"))
        same_time = (str(fm.get("startTime", "")) == ("" if all_day else data["start"]))
        if fm.get("title") == title and str(fm.get("date", ""))[:10] == d.isoformat() and same_time:
            print(f)
            return 0
    base = f"{d.isoformat()} {safe_name(title)}"
    path, n = FOLDER / f"{base}.md", 2
    while path.exists():
        path, n = FOLDER / f"{base} ({n}).md", n + 1
    path.write_text("\n".join(lines))
    print(path)
    return 0


def frontmatter(text: str) -> dict:
    m = re.match(r"---\n(.*?)\n---", text, re.S)
    out = {}
    if not m:
        return out
    for line in m.group(1).splitlines():
        k, sep, v = line.partition(":")
        if not sep:
            continue
        v = v.strip()
        if v.startswith('"'):
            try:
                v = json.loads(v)
            except ValueError:
                v = v.strip('"')
        out[k.strip()] = v
    return out


def list_all() -> int:
    out = []
    for f in sorted(FOLDER.glob("*.md")) if FOLDER.exists() else []:
        fm = frontmatter(f.read_text(errors="replace"))
        try:
            d = date.fromisoformat(str(fm.get("date", ""))[:10])
        except ValueError:
            continue
        all_day = str(fm.get("allDay", "")).lower() == "true" or not fm.get("startTime")
        if all_day:
            start = datetime(d.year, d.month, d.day).astimezone()
            end_d = date.fromisoformat(str(fm["endDate"])[:10]) + timedelta(days=1) if fm.get("endDate") else d + timedelta(days=1)
            end = datetime(end_d.year, end_d.month, end_d.day).astimezone()
        else:
            start = datetime.combine(d, datetime.strptime(fm["startTime"], "%H:%M").time()).astimezone()
            et = fm.get("endTime") or (start + timedelta(hours=1)).strftime("%H:%M")
            end = datetime.combine(d, datetime.strptime(et, "%H:%M").time()).astimezone()
            if end <= start:
                end += timedelta(days=1)
        out.append({"title": fm.get("title") or f.stem, "start": int(start.timestamp()), "end": int(end.timestamp()),
                    "allDay": all_day, "location": fm.get("location", ""), "cal": "Obsidian",
                    "path": str(f), "rel": str(f.relative_to(VAULT))})
    print(json.dumps(out, ensure_ascii=False))
    return 0


def delete(p: str) -> int:
    f = Path(p).resolve()
    if f.parent != FOLDER.resolve() or f.suffix != ".md":
        print("termin.py: nur Notizen im Termine-Ordner", file=sys.stderr)
        return 1
    f.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "add" and len(sys.argv) == 3:
        sys.exit(add(json.loads(sys.argv[2])))
    if cmd == "delete" and len(sys.argv) == 3:
        sys.exit(delete(sys.argv[2]))
    if cmd == "list":
        sys.exit(list_all())
    print(__doc__.strip(), file=sys.stderr)
    sys.exit(2)
