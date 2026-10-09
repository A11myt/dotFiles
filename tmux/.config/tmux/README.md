# tmux –Configuration

Diese tmux-Konfiguration ist Teil meines modularen Wayland-Setups.
Ziel: maximale Klarheit bei minimaler visueller Last.

---

## 🎨 Color System

### Accent & Base Colors

```tmux
set -g @accent       "#ff6a00"
set -g @fg_default   "#dcdfe4"
set -g @fg_dim       "#a9a9a9"
set -g @fg_muted     "#666666"
set -g @fg_active    "#ffffff"
set -g @bg_status    "#0f0f0f"
```

---

## 🌈 Truecolor Support

```tmux
set-option -ga terminal-overrides ',xterm-256color:Tc'
```

Erforderlich für:

* exakte Hex-Farben
* konsistente Darstellung mit Alacritty
* saubere Theme-Integration

---

## 🧱 Statusbar – Ultra Minimal

```tmux
set -g status on
set -g status-interval 1
set -g status-position bottom
set -g status-justify centre
set -g status-style "bg=#{@bg_status},fg=#{@fg_default}"
```

Design-Ziel:

* flach
* kein Gradient
* keine Box-Optik
* kein Hintergrundwechsel pro Segment

---

## 📏 Status Limits

```tmux
set -g status-left-length 30
set -g status-right-length 80
```

Kompakt gehalten

---

## ◀ LEFT – Session Indicator

```tmux
set -g status-left '#[bold,fg=#{@accent}]• #[nobold,fg=#{@fg_default}]#S '
```

* Orange Punkt = visuelles Anchor-Element
---

## ▶ RIGHT – Minimal Widget

```tmux
set -g status-right '\
#[fg=#{@fg_muted}]◦ \
#[nobold,fg=#{@accent}]%Y-%m-%d \
#[fg=#{@fg_muted}]▢ #(whoami) \
'
```

Inhalt:

* Ring Symbol
* Datum in Orange
* User in dezenter Grau-Ton

Kein Uhrzeit-Overload.
Kein CPU/RAM-Noise.

---

## 🪟 Window Styling

### Inactive Windows

```tmux
set-window-option -g window-status-format ' #[fg=#{@fg_muted}]#I #[fg=#{@fg_dim}]#W '
```

---

### Active Window

```tmux
set-window-option -g window-status-current-format ' #[bold,fg=#{@accent}]• #[fg=#{@fg_active}]#W #[nobold]'
```

---

## 🧩 Pane Styling

```tmux
set -g pane-border-status top
set -g pane-border-style "fg=#444444"
set -g pane-active-border-style "fg=#444444"
```


---

### Pane Title (Dot-Matrix via Bold)

```tmux
set -g pane-border-format " #[bold]#[fg=#ff6a00]#{pane_host}#{b:pane_current_path}#[nobold] "
```

* Host + Path
* Orange
* Bold → NDOT

---

## 📜 History

```tmux
set -g history-limit 100
```

Bewusst niedrig gehalten.
Terminal ist kein Log-Archiv.

---


## 🔗 Integration

Dieses tmux-Setup ist abgestimmt auf:

* Alacritty (Truecolor + NDOT Bold)
* Hyprland (Monochrome + Orange Accent)
* Waybar (Nothing OS Stil)

---

## 🚀 Ziel

Reduktion schafft Fokus.
Fokus schafft Geschwindigkeit.
Geschwindigkeit schafft Kontrolle.

