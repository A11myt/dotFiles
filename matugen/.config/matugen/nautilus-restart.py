#!/usr/bin/env python3
"""Nautilus neu starten, damit er neue GTK4-Farben lädt – offene Fenster bleiben erhalten.

GTK4 liest ~/.config/gtk-4.0/gtk.css nur beim Start. Vorher wird gemerkt:
  - welche Ordner offen sind      (D-Bus: org.freedesktop.FileManager1.OpenWindowsWithLocations)
  - wo die Fenster liegen         (hyprctl clients: Arbeitsfläche, schwebend, Position, Größe)
Danach wird alles so wieder geöffnet. Tabs lassen sich von außen nicht öffnen → weitere Tabs
kommen als eigene Fenster auf dieselbe Arbeitsfläche.

Läuft Nautilus nur ohne Fenster im Hintergrund, wird er einfach beendet.
"""
import json
import subprocess
import sys
import time
from urllib.parse import unquote, urlparse

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

CLASS = "org.gnome.Nautilus"
HOME_URI = GLib.filename_to_uri(GLib.get_home_dir())


def hypr_clients() -> list[dict]:
    out = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True).stdout
    return [c for c in json.loads(out or "[]") if c.get("class") == CLASS]


def dispatch(lua: str) -> None:
    subprocess.run(["hyprctl", "dispatch", lua], capture_output=True)


def open_locations() -> list[list[str]]:
    """Ordner pro Nautilus-Fenster (erstes Element = erster Tab)."""
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SESSION)
        res = bus.call_sync("org.freedesktop.FileManager1", "/org/freedesktop/FileManager1",
                            "org.freedesktop.DBus.Properties", "Get",
                            GLib.Variant("(ss)", ("org.freedesktop.FileManager1",
                                                  "OpenWindowsWithLocations")),
                            None, Gio.DBusCallFlags.NONE, 2000, None)
    except GLib.Error:
        return []
    windows = res.unpack()[0]
    # nach Fensternummer sortiert = Öffnungsreihenfolge
    return [windows[k] for k in sorted(windows, key=lambda p: int(p.rsplit("/", 1)[-1]))]


def title_for(uri: str) -> str:
    """So betitelt Nautilus ein Fenster für diesen Ordner (Anzeigename)."""
    if uri.rstrip("/") == HOME_URI:
        return "Home"
    try:
        info = Gio.File.new_for_uri(uri).query_info("standard::display-name", 0, None)
        return info.get_display_name()
    except GLib.Error:
        return unquote(urlparse(uri).path.rstrip("/").rsplit("/", 1)[-1])


def snapshot() -> list[dict]:
    """Verbindet D-Bus-Fenster (Ordner) mit Hyprland-Fenstern (Lage) über den Titel."""
    clients = hypr_clients()
    plans, used = [], set()
    for tabs in open_locations():
        names = {title_for(u): u for u in tabs}
        match = next((c for c in clients if c["address"] not in used and c["title"] in names), None)
        if match is None:
            match = next((c for c in clients if c["address"] not in used), None)
        if match:
            used.add(match["address"])
            active = names.get(match["title"], tabs[0])
            tabs = [active] + [u for u in tabs if u != active]
        plans.append({"tabs": tabs, "client": match})
    return plans


def wait_for_windows(known: set[str], titles: list[str], timeout: float = 15.0) -> list[dict]:
    """Wartet, bis alle neuen Fenster da sind und ihren Ordnertitel tragen (nicht "Loading…")."""
    end = time.monotonic() + timeout
    new: list[dict] = []
    while time.monotonic() < end:
        new = [c for c in hypr_clients() if c["address"] not in known]
        if len(new) >= len(titles) and sorted(c["title"] for c in new) == sorted(titles):
            return new
        time.sleep(0.1)
    return new


def place(new: dict, old: dict | None) -> None:
    if not old:
        return
    sel = f'window = "address:{new["address"]}"'
    dispatch(f'hl.dsp.window.move({{ workspace = {old["workspace"]["id"]}, {sel}, silent = true }})')
    if old.get("floating"):
        w, h = old["size"]
        x, y = old["at"]
        dispatch(f'hl.dsp.window.float({{ action = "enable", {sel} }})')
        # erst Größe, dann Position – sonst verschiebt das Verkleinern um die Mitte
        dispatch(f"hl.dsp.window.resize({{ x = {w}, y = {h}, exact = true, {sel} }})")
        dispatch(f"hl.dsp.window.move({{ x = {x}, y = {y}, exact = true, {sel} }})")


def main() -> int:
    if subprocess.run(["pgrep", "-x", "nautilus"], capture_output=True).returncode != 0:
        return 0
    plans = snapshot()
    active_before = json.loads(subprocess.run(["hyprctl", "activewindow", "-j"],
                                              capture_output=True, text=True).stdout or "{}")

    subprocess.run(["nautilus", "-q"], capture_output=True)
    for _ in range(100):  # bis zu 5 s auf sauberes Beenden warten (auch D-Bus-Name frei)
        gone = subprocess.run(["pgrep", "-x", "nautilus"], capture_output=True).returncode != 0
        if gone and not Gio.bus_get_sync(Gio.BusType.SESSION).call_sync(
                "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                "NameHasOwner", GLib.Variant("(s)", ("org.gnome.Nautilus",)),
                None, Gio.DBusCallFlags.NONE, 1000, None).unpack()[0]:
            break
        time.sleep(0.05)
    if not plans:
        return 0

    # (uri, Ziel-Lage) – Tab 1 bekommt die volle Lage, weitere Tabs nur die Arbeitsfläche
    jobs = []
    for plan in plans:
        for i, uri in enumerate(plan["tabs"]):
            c = plan["client"]
            jobs.append((uri, c if i == 0 else ({"workspace": c["workspace"]} if c else None),
                         i == 0 and c is not None and c["address"] == active_before.get("address")))

    # alle Ordner in einem Aufruf öffnen – ein Kaltstart statt vieler
    known = {c["address"] for c in hypr_clients()}
    subprocess.Popen(["nautilus", "--new-window", *[u for u, _, _ in jobs]], start_new_session=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    new = wait_for_windows(known, [title_for(u) for u, _, _ in jobs])

    focus_target = None
    for uri, old, was_active in jobs:
        win = next((c for c in new if c["title"] == title_for(uri)), None)
        if win is None:
            print(f"nautilus-restart: kein Fenster für {uri}", file=sys.stderr)
            continue
        new.remove(win)
        place(win, old)
        if was_active:
            focus_target = win["address"]

    # Fokus zurück: auf das vorher aktive Fenster (neu geöffnetes Nautilus oder andere App)
    target = focus_target or active_before.get("address")
    if target:
        dispatch(f'hl.dsp.focus({{ window = "address:{target}" }})')
    return 0


if __name__ == "__main__":
    sys.exit(main())
