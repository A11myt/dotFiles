# Alacritty Configuration

Minimal. Monochrome. Performance-first.

Diese Konfiguration ist Teil meines Wayland/Hyprland Setups und folgt der
„Nothing OS“-inspirierten Designlinie:

- Dunkler Hintergrund
- Monospace-Klarheit
- Orange (#ff6a00) als einziger Akzent
- Keine Fenster-Dekoration
- Subtile Transparenz

---

# 🧠 Design-Prinzipien

1. Kein visuelles Chaos
2. Monochrom mit kontrollierter Akzentfarbe
3. Lesbarkeit vor Effekten
4. Konfigurierbar & reproduzierbar

---

# 🔤 Typography

| Element | Font |
|---------|------|
| Normal | Iosevka Nerd Font Mono |
| Bold/Accent | NDOT 47 (inspired by NOTHING) |
| Size | 10 |
| Offset Y | +1 (optische Zentrierung) |

### Motivation

- **Iosevka Nerd Font Mono** → saubere Developer-Schrift
- **NDOT 47** → Dot-Matrix Look für visuelle Hierarchie (Prompts, Status, Headlines)

Bold wird bewusst optional gehalten, um visuelle Überladung zu vermeiden.

---

# 🎨 Color System

## Primary

- Background: `#0f0f0f`
- Foreground: `#f2f2f2`

## Accent

- Orange: `#ff6a00`
- Soft Orange: `#ffb366`
- Bright Orange: `#ff8a33`

Rot wird nicht als „Fehlerfarbe“, sondern als kontrollierter Akzent genutzt.

---

## Normal Colors

Monochrome mit Orange-Akzent statt klassischem 
black = #151515
red = #ff6a00
green = #bfbfbf
yellow = #ffb366
blue = #d0d0d0
magenta = #c8c8c8
cyan = #d8d8d8
white = #e5e5e5

---

# 🪟 Window Behavior

| Setting | Value |
|----------|--------|
| Opacity | 0.9 |
| Decorations | none |
| Padding | 18x20 |
| Dynamic Title | true |

Ziel:
- Floating-Fenster wirken wie „Panels“
- Keine sichtbare WM-Dekoration
- Subtile Glas-Optik

---

# ⌨ Cursor

- Shape: Beam
- Blinking: On
- Interval: 450ms
- Unfocused: hollow

Cursor bleibt minimal und kontrastreich.

---

# 📜 Scrolling

- History: 10000 lines
- Multiplier: 3

---

# 📂 Config Location

```bash
~/.config/alacritty/alacritty.toml
