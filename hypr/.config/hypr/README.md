# Hyprland (Lua-Config)

Hyprland 0.57 mit Lua-Konfiguration. Einstieg ist `hyprland.lua`, die übrigen Dateien werden von dort geladen.
`hyprland.conf` ist nur ein Platzhalter, den Hyprland selbst anlegt.

| Datei | Inhalt |
|---|---|
| `hyprland.lua` | Einstieg: lädt die anderen Dateien, legt Monitore und Eingabe (Tastatur, Touchpad) fest |
| `envvars.lua` | Umgebung (u. a. `PATH` mit `~/.local/bin` für Tastenkürzel, Qt/GTK-Themes) |
| `monitors.lua` | Monitore ein-/ausstecken: Arbeitsflächen 2/3 folgen externen Bildschirmen |
| `layout.lua` | Abstände, Rahmen, Unschärfe, Animationen, `misc` (siehe Hinweise) |
| `rules.lua` | Fenster- und Ebenen-Regeln (Drop-down-Terminal, schwebende Fenster, Unschärfe hinter `qs-*`) |
| `keybinds.lua` | alle Tastenkürzel – Abschnitte `-- ── Name ──`, Beschreibung als Kommentar hinter jedem `hl.bind` |
| `autostart.lua` | Schlüsselbund, SSH-Agent, Polkit, hypridle, Quickshell, Wallpaper, Zwischenablage-Verlauf, Sitzung wiederherstellen |
| `hypridle.conf` | dimmen → sperren (`~/.local/bin/lock`) → Bildschirm aus → Ruhezustand |
| `hyprlock.conf` | Rückfall-Sperrbildschirm, falls Quickshell nicht bereit ist |
| `themes/` | von Matugen/fontgen erzeugte Farben und Schriften (nicht versioniert) |

## Tastenkürzel

**SUPER+/** zeigt alle Kürzel als durchsuchbare Übersicht. Sie wird direkt aus `keybinds.lua` gelesen –
neue Kürzel brauchen nur einen Kommentar hinter dem `hl.bind`, damit sie dort mit Beschreibung erscheinen:

```lua
-- ── Programme & Oberfläche ──
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))   -- Terminal
```

Für Schleifen (Arbeitsflächen 1–10) gibt es die Form `-- @ TASTEN | Beschreibung`.

## Hinweise

- **Absturz beim Standard-Wallpaper (0.57):** `force_default_wallpaper = 0` und `disable_hyprland_logo = true`
  in `layout.lua` nicht zurücksetzen.
- **`allow_session_lock_restore = true`:** stürzt der Sperrbildschirm ab, kann ein neuer übernehmen
  (z. B. aus einer TTY: `hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'`).
- **Befehle aus Tastenkürzeln** laufen mit dem `PATH` aus `envvars.lua` – eigene Werkzeuge liegen in `~/.local/bin`.
- **Prüfen nach Änderungen:** `hyprctl reload && hyprctl configerrors` (leer = gut), danach `dotdoctor`.
