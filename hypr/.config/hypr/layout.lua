local ok, colors = pcall(require, "themes.matugen")
if not ok then
    colors = { primary = "rgba(fdb0d4ff)", on_secondary = "rgba(412a34ff)" }
end

hl.config({
    general = {
        border_size      = 2,
        gaps_in          = 2,
        gaps_out         = 5,
        col = {
            active_border   = colors.primary,
            inactive_border = colors.on_secondary,
        },
        resize_on_border = true,
        allow_tearing    = true,
        layout           = "master",
    },

    decoration = {
        rounding         = 10,
        rounding_power   = 3,
        active_opacity   = 1.0,
        inactive_opacity = 0.98,
        fullscreen_opacity = 1.0,
        dim_inactive     = true,
        dim_strength     = 0.05,

        shadow = {
            enabled      = true,
            range        = 12,
            render_power = 5,
            color        = "rgba(12121244)",
        },

        blur = {
            enabled           = true,
            size              = 15,
            passes            = 3,
            contrast          = 0.8,
            brightness        = 1.2,
            noise             = 0.09,
            vibrancy          = 0.1696,
            new_optimizations = false,
            xray              = false,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
        force_split    = 0,
        smart_split    = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = false,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}   } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}   } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}      } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1.0} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}    } })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 5,    bezier = "easeOutQuint" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3,    bezier = "quick" })
hl.animation({ leaf = "border",        enabled = true,  speed = 3,    bezier = "easeOutQuint" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 5,    bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",        style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",        style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "slidefade 10%" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "slidefade 10%" })
