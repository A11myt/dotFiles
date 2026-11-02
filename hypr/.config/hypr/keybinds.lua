local mainMod     = "SUPER"
local terminal    = "alacritty"
local fileManager = "nautilus"
local menu        = "qs ipc call launcher apps"          -- Launcher (Quickshell)

-- ── Fenster ──
hl.bind(mainMod .. " + C", hl.dsp.window.close())   -- Fenster schließen
hl.bind(mainMod .. " + M", hl.dsp.exit())   -- Hyprland beenden
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))   -- Fenster schwebend/gekachelt
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))   -- Launcher (Apps, Rechner, Emoji …)
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())   -- Pseudo-Kacheln
hl.bind(mainMod .. " + O", hl.dsp.layout("togglesplit"))   -- Teilung drehen
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())   -- Vollbild
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd([[if [ "$(hyprctl getoption general:layout -j | jq -r .str)" = master ]; then L=dwindle; else L=master; fi; hyprctl eval "hl.config({ general = { layout = '$L' } })"]]))   -- Layout master ↔ dwindle

-- ── Programme & Oberfläche ──
hl.bind(mainMod .. " + Q",            hl.dsp.exec_cmd(terminal))   -- Terminal
hl.bind(mainMod .. " + E",            hl.dsp.exec_cmd(fileManager))   -- Dateien (Nautilus)
hl.bind(mainMod .. " + CTRL + O",     hl.dsp.exec_cmd("flatpak run md.obsidian.Obsidian"))   -- Obsidian
hl.bind("Print",                      hl.dsp.exec_cmd("qs ipc call screenshot region"))   -- Screenshot: Bereich (Klick = Fenster)
hl.bind("Insert",                     hl.dsp.exec_cmd("qs ipc call screenshot region"))   -- Screenshot: Bereich
hl.bind("SHIFT + Print",              hl.dsp.exec_cmd("qs ipc call screenshot window"))   -- Screenshot: Fenster
hl.bind("CTRL + Print",               hl.dsp.exec_cmd("qs ipc call screenshot screen"))   -- Screenshot: ganzer Bildschirm
hl.bind("ALT + Print",                hl.dsp.exec_cmd("qs ipc call screenshot record"))   -- Bildschirmaufnahme starten/stoppen
hl.bind(mainMod .. " + A",            hl.dsp.exec_cmd("qs ipc call panels toggle center"))   -- Benachrichtigungszentrale
hl.bind(mainMod .. " + S",            hl.dsp.exec_cmd("qs ipc call panels toggle quick"))   -- Quick Settings
hl.bind(mainMod .. " + grave",        hl.dsp.exec_cmd("~/.local/bin/dropdown"))   -- Drop-down-Terminal
hl.bind(mainMod .. " + TAB",          hl.dsp.exec_cmd("qs ipc call overview toggle"))   -- Fensterübersicht
hl.bind(mainMod .. " + I",            hl.dsp.exec_cmd("qs ipc call settings toggle"))   -- Einstellungen
hl.bind(mainMod .. " + SHIFT + V",    hl.dsp.exec_cmd("qs ipc call panels toggle clipboard"))   -- Zwischenablage-Verlauf
hl.bind(mainMod .. " + H",            hl.dsp.exec_cmd("hyprpicker -a -n -l"))   -- Farbpipette (Farbe kopieren)
hl.bind(mainMod .. " + W",            hl.dsp.exec_cmd("qs ipc call launcher wallpapers"))   -- Wallpaper wählen
hl.bind(mainMod .. " + slash",        hl.dsp.exec_cmd("qs ipc call cheatsheet toggle"))   -- Tastenkürzel-Übersicht
hl.bind(mainMod .. " + B",            hl.dsp.exec_cmd("qs ipc call sidebar toggle"))   -- Info-Leiste rechts

-- ── System ──
hl.bind(mainMod .. " + l",            hl.dsp.exec_cmd("loginctl lock-session"))   -- Sperren
hl.bind("CTRL + ALT + DELETE",        hl.dsp.exec_cmd("qs ipc call power toggle"))   -- Power-Menü

-- ── Fenster verschieben ──
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))   -- Fenster nach links schieben
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))   -- Fenster nach rechts schieben
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))   -- Fenster nach oben schieben
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))   -- Fenster nach unten schieben

-- ── Fokus ──
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))   -- Fokus links
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))   -- Fokus rechts
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))   -- Fokus oben
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))   -- Fokus unten

-- ── Größe ändern ──
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.resize({ x = -5, y = 0  }))   -- schmaler
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 5,  y = 0  }))   -- breiter
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0,  y = -5 }))   -- niedriger
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0,  y = 5  }))   -- höher

-- ── Arbeitsflächen ──
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))          -- @ SUPER + 1…0 | zu Arbeitsfläche 1–10
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))    -- @ SUPER + SHIFT + 1…0 | Fenster auf Arbeitsfläche 1–10
end

-- ── Arbeitsflächen (Maus) ──
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))   -- nächste Arbeitsfläche
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))   -- vorherige Arbeitsfläche

-- ── Maus ──
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })   -- Fenster ziehen
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })   -- Fenstergröße ziehen

-- ── Lautstärke & Helligkeit ──
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })   -- lauter
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })   -- leiser
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })   -- stumm
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })   -- Mikrofon stumm
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -q set +5% && qs ipc call osd brightness"),                          { locked = true, repeating = true })   -- heller
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -q set 5%- && qs ipc call osd brightness"),                          { locked = true, repeating = true })   -- dunkler

-- ── Medien ──
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })   -- nächster Titel
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })   -- Pause
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })   -- Wiedergabe/Pause
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })   -- vorheriger Titel
