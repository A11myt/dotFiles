# dotFiles

Arch Linux · Hyprland (Lua-Config) · Quickshell-Oberfläche · Matugen-Farben aus dem Wallpaper · ThinkPad T470

Verwaltet mit **GNU stow**: jedes Verzeichnis hier ist ein Paket, dessen Inhalt nach `$HOME` gespiegelt wird.
`~/.config/hypr` ist z. B. ein Symlink auf `hypr/.config/hypr` in diesem Repo – Änderungen landen direkt hier.
Immer mit Ziel aufrufen: `stow --target="$HOME" <paket>` (ohne Ziel verlinkt stow ins Elternverzeichnis des Repos).

## Pakete

| Paket | Ziel | Inhalt |
|---|---|---|
| `hypr` | `~/.config/hypr` | Hyprland (Lua), hyprlock (Rückfall), hypridle |
| `quickshell` | `~/.config/quickshell` | gesamte Oberfläche (QML), siehe unten – früher AGS: `git checkout ags-final` |
| `matugen` | `~/.config/matugen` | Farb-Templates für alle Apps, `wallthemes.toml`, Timer für Hell/Dunkel und Nachtlicht |
| `fontgen` | `~/.config/fontgen` | Schrift-Profile (wie Matugen, nur für Schriften) |
| `alacritty` | `~/.config/…` | Terminal |
| `nvim` | `~/.config/nvim` | AstroNvim v5 |
| `tmux` | `~/.config/tmux` | tmux-Config + Keybinds (auch im Drop-down-Terminal) |
| `gtk`, `qt` | `~/.config/…` | GTK-3/4- und Qt-5/6-Einstellungen (Farben/Schrift kommen von Matugen/fontgen) |
| `scripts` | `~/.config/scripts` | `log.sh` – gemeinsames Logging nach `~/.logs/<tool>/` |
| `pacman` | `~/.config/pacman` | `makepkg.conf`: keine `-debug`-Pakete bei AUR-Builds |
| `zsh`, `git` | `~` | Shell, Git |
| `bin` | `~/.local/bin` | eigene Werkzeuge, siehe unten |
| `backup` | `~/.config/backup`, systemd | restic-Backup von `~` (Timer) |
| `session` | `~/.config/session`, systemd | offene Programme merken und nach dem Login wiederherstellen |

Nicht gestowt:

| Ordner | Zweck |
|---|---|
| `system/` | Dateien für `/etc` (greetd + ReGreet-Login, PAM-Keyring-Unlock, Akku-Ladegrenzen, Timeshift) – `install.sh --system` |
| `packages/` | `pkglist.txt` (Repos), `aur.txt`, `flatpak.txt` |
| `windows/wintheme/` | **Matugen für Windows 11**: Windows-Akzentfarbe, Windows Terminal, VS Code aus dem Wallpaper – Anleitung im Ordner |
| `hooks/` | `pre-commit`: Secret-Check (Repo ist öffentlich) – blockiert u. a. Tokens, Schlüssel, private Kalender-Adressen |

## Oberfläche (Quickshell)

Alle Tastenkürzel zeigt **SUPER+/** (wird aus `hypr/.config/hypr/keybinds.lua` gelesen). Die wichtigsten:

| Taste | Funktion |
|---|---|
| SUPER+R / SUPER+W | Launcher (Apps, `12*3`, `:emoji`, `>befehl`, `g suche`, Aktionen) / Wallpaper wählen |
| SUPER+S | Quick Settings – Unterseiten WLAN, Bluetooth, Audio, Kacheln Nachtlicht und Hell/Dunkel |
| SUPER+B | Dashboard rechts – Widgets frei wählbar (Wetter, Nachrichten nach Themen, Termine, E-Mail, Twitch, System, Gesundheit, Akkus …) |
| SUPER+I | Einstellungen – Farben, Schrift, Dashboard, Nachrichten, Leiste, Fokus, Kalender, Konten |
| SUPER+K / SUPER+Shift+K | Kalender / große Monatsansicht mit „+ Termin“ |
| SUPER+Tab | Fensterübersicht mit Live-Vorschau |
| SUPER+A | Benachrichtigungszentrale |
| SUPER+Shift+V | Zwischenablage-Verlauf |
| SUPER+` | Drop-down-Terminal (tmux) |
| SUPER+Shift+P | Fokus-Timer (Pomodoro, „Nicht stören“ während Fokus) |
| Druck / Shift+Druck / Strg+Druck | Screenshot Bereich / Fenster / Bildschirm (`satty` zum Markieren) |
| Alt+Druck | Bildschirmaufnahme starten/stoppen (`wf-recorder`) |
| SUPER+L | Sperren (Quickshell, Rückfall hyprlock) |

Einstellungen der Oberfläche stehen in `quickshell/.config/quickshell/config.json` (versioniert).
**Private Daten liegen bewusst nicht im Repo:**

| Was | Wo |
|---|---|
| Kalender-Adressen (iCal, geheim) | `~/.local/share/quickshell/calendars.json` (Rechte 600) |
| Postfächer | `~/.local/share/quickshell/mail.json` (Rechte 600) |
| Mail-Passwörter, Twitch-API, restic | Schlüsselbund (`secret-tool`, Dienste `qs-mail`, `qs-twitch`, `restic`) |
| eigene Termine | Obsidian-Vault, Ordner `Termine/` (Notizen, Format wie Plugin „Full Calendar“) |

## Eigene Werkzeuge (`bin`)

| Befehl | Zweck |
|---|---|
| `wallthemes` | Matugen mit Cache pro Wallpaper; `state`/`set`/`pick`, `auto on\|off` (Hell/Dunkel nach Sonnenstand) |
| `fontgen` | Schrift-Profile systemweit setzen (`use`, `size`, `state`) |
| `nightlight` | Blaulichtfilter (hyprsunset) nach Sonnenstand, sanfter Übergang |
| `dotdoctor` | Gesundheits-Check des ganzen Setups (`--json` fürs Dashboard, `--updates`) |
| `session` | offene Programme merken/wiederherstellen |
| `backup` | restic-Backup von `~` |
| `akku` | Akku-Ladegrenzen (`schonen` 75–80 %, `voll`) |
| `lock` | Sperren: Quickshell, wenn bereit – sonst hyprlock |
| `dropdown` | Drop-down-Terminal ein-/ausblenden |

## Installation

```bash
git clone git@github.com:A11myt/dotFiles.git ~/Workspace/Github/dotfiles
cd ~/Workspace/Github/dotfiles
./install.sh --packages --system     # ohne Flags: nur stow + Hook + Timer
dotdoctor                            # danach: ist alles grün?
```

Matugen-Farbdateien sind nicht versioniert (ändern sich mit jedem Wallpaper); `install.sh` erzeugt ein Startschema,
danach Wallpaper mit `SUPER+W` wählen. Kalender, Postfächer und Twitch einmal unter SUPER+I einrichten.

## Alltag

```bash
stow --target="$HOME" -n -v <paket>  # Probelauf
stow --target="$HOME" <paket>        # verlinken  ·  stow --target="$HOME" -D <paket>  entlinken
pacman -Qqen > packages/pkglist.txt && pacman -Qqem | grep -v -- -debug$ > packages/aur.txt   # Paketlisten aktualisieren
qs-restart                           # Oberfläche neu starten (Log: ~/.logs/quickshell.log)
```
