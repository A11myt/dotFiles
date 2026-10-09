# dotFiles

Arch Linux · Hyprland (Lua-Config) · AGS-Bar · Matugen-Farben aus dem Wallpaper · ThinkPad T470

Verwaltet mit **GNU stow**: jedes Verzeichnis hier ist ein Paket, dessen Inhalt nach `$HOME` gespiegelt wird.
`~/.config/hypr` ist z.B. ein Symlink auf `hypr/.config/hypr` in diesem Repo – Änderungen landen direkt hier.

## Pakete

| Paket | Ziel | Inhalt |
|---|---|---|
| `hypr` | `~/.config/hypr` | Hyprland (Lua), hyprlock, hypridle |
| `ags` | `~/.config/ags` | Statusleiste (AGS v3, TypeScript) inkl. Update-Modul |
| `matugen` | `~/.config/matugen` | Farbschema-Templates, `wallpaper.sh`, Wallpaper-Picker (`SUPER+W`) |
| `alacritty` `rofi` `swaync` `wlogout` | `~/.config/…` | Terminal, Launcher, Notifications, Power-Menü |
| `nvim` | `~/.config/nvim` | AstroNvim v5 |
| `tmux` | `~/.config/tmux` | tmux-Config + Keybinds |
| `scripts` | `~/.config/scripts` | `log.sh` – gemeinsames Logging nach `~/.logs/<tool>/` |
| `pacman` | `~/.config/pacman` | `makepkg.conf`: keine `-debug`-Pakete bei AUR-Builds |
| `zsh` | `~` | `.zshrc`, `.zprofile`, `.p10k.zsh` |
| `git` | `~` | `.gitconfig`, globales `~/.config/git/ignore` |
| `bin` | `~/.local/bin` | `ssh-askpass-keyring.sh`, `godot-nvim` |

Nicht gestowt:

| Ordner | Zweck |
|---|---|
| `system/` | Dateien für `/etc` (greetd + ReGreet-Login, PAM-Keyring-Unlock, Timeshift) – werden von `install.sh --system` kopiert |
| `packages/` | `pkglist.txt` (Repos), `aur.txt`, `flatpak.txt` |
| `hooks/` | `pre-commit`: Secret-Check (Repo ist öffentlich) |

## Installation

```bash
git clone git@github.com:A11myt/dotFiles.git ~/Workspace/Github/dotfiles
cd ~/Workspace/Github/dotfiles
./install.sh --packages --system     # ohne Flags: nur stow + Hook
```

Matugen-Farbdateien sind nicht versioniert (ändern sich mit jedem Wallpaper); `install.sh` erzeugt ein Startschema, danach Wallpaper mit `SUPER+W` wählen.

## Alltag

```bash
stow -n -v <paket>     # Probelauf
stow <paket>           # verlinken      ·  stow -D <paket>  entlinken
pacman -Qqen > packages/pkglist.txt && pacman -Qqem | grep -v -- -debug$ > packages/aur.txt   # Paketlisten aktualisieren
```
