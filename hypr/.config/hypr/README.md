
# Hyprland – a11myt Configuration

Diese Konfiguration ist Teil meines modularen Arch/Wayland-Setups.
Fokus:

* Master-Layout als produktiver Default
* Subtile Blur- & Dim-Effekte
* Kontrollierte Animationen
* Klare Shortcut-Architektur
* Reproduzierbare Dependencies

---

## 🎨 Look & Feel

### General

* Border size: 2px
* Gaps in: 2
* Gaps out: 5
* Resize on border: enabled
* Default layout: `master`
* Tearing: enabled

#### Border Colors

* Active: `rgba(ffffffaa)`
* Inactive: `rgba(2a2a2a88)`

Ziel: ruhiger Kontrast ohne aggressive Akzentfarbe.

---

### Decoration

* Rounding: 10
* Active opacity: 1
* Inactive opacity: 0.98
* Dim inactive: enabled (0.05)
* Blur enabled
* Blur size: 15
* Passes: 3
* Contrast: 0.8
* Brightness: 1.2
* Vibrancy: 0.1696

#### Shadows

* Enabled
* Range: 12
* Color: `rgba(12121244)`

Fenster wirken wie Panels, nicht wie harte Kacheln.

---

## 🎬 Animations

Animations sind weich, aber nicht verspielt.

Custom Bezier Curves:

* easeOutQuint
* easeInOutCubic
* almostLinear
* quick
* linear

Aktive Animationen:

* windows
* fade
* border
* workspaces (slidefade)
* layers
* popin transitions

Kein Zoom-Overkill.
Nur subtile Übergänge.

---

## 🎯 Keybindings

Main Modifier:

```
$mainMod = SUPER
```

---

### Core Applications

| Shortcut         | Action       | Dependency                   |
| ---------------- | ------------ | ---------------------------- |
| SUPER + Q        | Terminal     | alacritty                    |
| SUPER + E        | File Manager | thunar                       |
| SUPER + R        | Launcher     | wofi / rofi                  |
| SUPER + L        | Lock         | hyprlock                     |
| SUPER + CTRL + O | Obsidian     | flatpak md.obsidian.Obsidian |

---

### Window Management

| Shortcut              | Action             |
| --------------------- | ------------------ |
| SUPER + C             | Kill active window |
| SUPER + V             | Toggle floating    |
| SUPER + F             | Fullscreen         |
| SUPER + Arrow         | Move focus         |
| SUPER + SHIFT + Arrow | Move window        |
| SUPER + CTRL + Arrow  | Resize active      |
| SUPER + Mouse Drag    | Move / Resize      |

---

### Workspace Control

* SUPER + 1–0 → Switch workspace
* SUPER + SHIFT + 1–0 → Move window
* SUPER + Scroll → Cycle workspaces

---

### Layout Control

| Shortcut  | Action         |
| --------- | -------------- |
| SUPER + P | Pseudotile     |
| SUPER + O | Toggle split   |
| SUPER + D | Toggle dwindle |

---

### Screenshot

Insert key:

```bash
grim -g "$(slurp)" ~/Pictures/screenshot_$(date +%s).png
```

Dependencies:

* grim
* slurp

---

### Audio & Media

Dependencies:

* pipewire
* wireplumber
* wpctl
* playerctl

Shortcuts:

* XF86AudioRaiseVolume
* XF86AudioLowerVolume
* XF86AudioMute
* XF86AudioMicMute
* XF86AudioNext
* XF86AudioPrev
* XF86AudioPlay

---

### Brightness

Dependency:

* brightnessctl

---

### Waybar Restart

Shortcut:

```
SUPER + A
```

Executes:

```bash
~/.config/waybar/scripts/launch.sh
```

---

## 🎨 Color Tokens

```ini
$bg0 = #0f0f0f
$bg1 = #151515
$bg2 = #1a1a1a

$fg0 = #ffffff
$fg1 = #d0d0d0
$fg2 = #9d9d9d

$border = #2a2a2a
$accent = #e9e9e9
```

Monochrome-first.
Accent nur subtil für Hover / Active.

---

## 📦 Required Packages

```bash
sudo pacman -S hyprland
sudo pacman -S alacritty
sudo pacman -S thunar
sudo pacman -S wofi
sudo pacman -S hyprlock
sudo pacman -S grim slurp
sudo pacman -S brightnessctl
sudo pacman -S playerctl
sudo pacman -S pipewire wireplumber
```

Optional:

* waybar
* hyprpaper
* swaync

