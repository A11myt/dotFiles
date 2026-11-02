#!/usr/bin/env python3
"""System-Gesundheit für das Dashboard: dotdoctor, Updates (von der Leiste), Arch-News
seit dem letzten Systemupdate. Ausgabe JSON, außerdem in ~/.cache/quickshell/health.json.

  health.py            neu prüfen (dotdoctor ~4 s, Arch-News aus dem Cache von news.py)
"""
import json
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

HOME = Path.home()
HERE = Path(__file__).resolve().parent
OUT = HOME / ".cache/quickshell/health.json"
ARCH_FEED = [{"name": "Arch Linux", "url": "https://archlinux.org/feeds/news/"}]


def last_upgrade() -> int:
    """Zeitpunkt des letzten `pacman -Syu` aus /var/log/pacman.log (0 = unbekannt)."""
    try:
        lines = Path("/var/log/pacman.log").read_text(errors="replace").splitlines()
    except OSError:
        return 0
    for line in reversed(lines):
        if "starting full system upgrade" in line:
            m = re.match(r"\[([^\]]+)\]", line)
            if m:
                try:
                    return int(datetime.fromisoformat(m.group(1)).timestamp())
                except ValueError:
                    return 0
    return 0


def main() -> int:
    r = subprocess.run([str(HOME / ".local/bin/dotdoctor"), "--json"], capture_output=True, text=True)
    try:
        doctor = json.loads(r.stdout)["results"]
    except (ValueError, KeyError):
        doctor = [{"section": "dotdoctor", "state": "fail", "msg": "dotdoctor lieferte kein Ergebnis", "detail": r.stderr.splitlines()[-3:]}]

    try:
        updates = json.loads((HOME / ".cache/quickshell/updates.json").read_text())
    except (OSError, ValueError):
        updates = {"time": 0, "pkgs": [], "reboot": ""}

    since = last_upgrade()
    news = []
    try:
        n = subprocess.run([sys.executable, "-I", str(HERE / "news.py"), json.dumps(ARCH_FEED)],
                           capture_output=True, text=True, timeout=20)
        news = [x for x in json.loads(n.stdout) if not x.get("error") and x["time"] > since][:5]
    except (subprocess.TimeoutExpired, ValueError):
        pass

    out = {"time": int(time.time()), "doctor": doctor, "updates": updates,
           "lastUpgrade": since, "archNews": news}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, ensure_ascii=False))
    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
