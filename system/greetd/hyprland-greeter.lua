-- Mini-Hyprland nur für den Login-Bildschirm (greetd → ReGreet)
-- Installiert nach /etc/greetd/hyprland-greeter.lua, Quelle: ~/.config/greetd/

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.env("XCURSOR_SIZE", "24")
hl.env("GTK_USE_PORTAL", "0")

hl.config({
    ["input.kb_layout"]  = "us",
    ["input.kb_options"] = "caps:escape",
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
    },
    animations = { enabled = true },
    decoration = {
        rounding = 10,
        blur = { enabled = true, size = 15, passes = 3 },
    },
})

hl.on("hyprland.start", function()
    -- Hyprland beenden, sobald ReGreet fertig ist (Login übergibt an die echte Session)
    hl.exec_cmd("regreet --style /var/lib/greeter-theme/regreet.css; hyprctl dispatch 'hl.dsp.exit()'")
end)
