-- suppress maximize from all apps
hl.window_rule({
    name          = "suppress-maximize-events",
    match         = { class = ".*" },
    suppress_event = "maximize",
})

-- fix XWayland drag issues
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- floating windows
hl.window_rule({ match = { class = "^(org\\.pulseaudio\\.pavucontrol)$" }, float = true })
hl.window_rule({ match = { class = "^(blueman-manager)$" }, float = true })

-- opacity rules (format: "active inactive")
hl.window_rule({ match = { class = "^(Rofi)$" },           opacity = "0.92 0.92" })
hl.window_rule({ match = { class = "^(wlogout)$" },        opacity = "0.92 0.92" })
hl.window_rule({ match = { class = "^(org\\.pulseaudio\\.pavucontrol)$" }, opacity = "0.85 0.85" })
hl.window_rule({ match = { class = "^(blueman-manager)$" },opacity = "0.88 0.88" })
hl.window_rule({ match = { class = "^(Alacritty)$" },      opacity = "0.90 0.90" })

-- conky
hl.window_rule({
    match     = { class = "^(conky)$" },
    no_anim   = true,
    no_focus  = true,
    no_shadow = true,
    opacity   = "0.90 0.90",
})

-- layer rules
hl.layer_rule({ match = { namespace = "logout_dialog" },            blur = true })
hl.layer_rule({ match = { namespace = "swaync-control-center" },    blur = true })
hl.layer_rule({ match = { namespace = "swaync-notification-window" }, blur = true })
