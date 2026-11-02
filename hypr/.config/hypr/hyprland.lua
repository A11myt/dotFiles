-- https://wiki.hypr.land/Configuring/Start/

require("envvars")
require("autostart")
require("monitors")   -- Arbeitsflächen 2/3 folgen externen Monitoren (Hotplug)
require("layout")
require("keybinds")
require("rules")

-- monitors
hl.monitor({ output = "eDP-1",    mode = "1920x1080@60", position = "0x0",    scale = 1 })
hl.monitor({ output = "DP-3",     mode = "1920x1080@60", position = "1920x0", scale = 1 })
hl.monitor({ output = "HDMI-A-2", mode = "1920x1080@60", position = "3840x0", scale = 1 })

-- input
hl.config({
    ["input.kb_layout"]            = "us",
    ["input.kb_options"]           = "caps:escape",
    ["input.follow_mouse"]         = 1,
    ["input.sensitivity"]          = 0,
    ["input.touchpad.natural_scroll"] = false,
})

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})
