local mainMod     = "SUPER"
local terminal    = "alacritty"
local fileManager = "nautilus"
local menu        = "pgrep -x rofi >/dev/null && pkill -x rofi || rofi -show drun"

-- compositor
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + O", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
-- Layout master <-> dwindle umschalten
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd([[if [ "$(hyprctl getoption general:layout -j | jq -r .str)" = master ]; then L=dwindle; else L=master; fi; hyprctl eval "hl.config({ general = { layout = '$L' } })"]]))

-- programs
hl.bind(mainMod .. " + Q",            hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E",            hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + CTRL + O",     hl.dsp.exec_cmd("flatpak run md.obsidian.Obsidian"))
hl.bind("Insert",                     hl.dsp.exec_cmd('grim -g "$(slurp)" - | tee ~/Pictures/screenshot_$(date +%s).png | wl-copy'))
hl.bind(mainMod .. " + A",            hl.dsp.exec_cmd("qs ipc call panels toggle center"))     -- Benachrichtigungszentrale
hl.bind(mainMod .. " + S",            hl.dsp.exec_cmd("qs ipc call panels toggle quick"))      -- Quick Settings
hl.bind(mainMod .. " + grave",        hl.dsp.exec_cmd("~/.local/bin/dropdown"))   -- Drop-down-Terminal (Taste links neben 1)
hl.bind(mainMod .. " + TAB",          hl.dsp.exec_cmd("qs ipc call overview toggle"))          -- Fensterübersicht
hl.bind(mainMod .. " + SHIFT + V",    hl.dsp.exec_cmd("qs ipc call panels toggle clipboard"))  -- Zwischenablage-Verlauf
hl.bind(mainMod .. " + H",            hl.dsp.exec_cmd("hyprpicker -a -n -l"))
hl.bind(mainMod .. " + W",            hl.dsp.exec_cmd("~/.config/matugen/wallpaper-picker.sh"))

-- system
hl.bind(mainMod .. " + l",            hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind("CTRL + ALT + DELETE",        hl.dsp.exec_cmd("qs ipc call power toggle"))             -- Power-Menü

-- move windows
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

-- focus
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- resize
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.resize({ x = -5, y = 0  }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 5,  y = 0  }))
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0,  y = -5 }))
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0,  y = 5  }))

-- workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- scroll through workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- mouse move/resize
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- multimedia keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -q set +5% && qs ipc call osd brightness"),                          { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -q set 5%- && qs ipc call osd brightness"),                          { locked = true, repeating = true })

-- playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
