hl.env("XCURSOR_SIZE",        "24")
hl.env("HYPRCURSOR_SIZE",     "24")
hl.env("GDK_SCALE",           "1")
hl.env("QT_SCALE_FACTOR",     "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")  -- Qt-Apps nutzen die Matugen-Palette aus ~/.config/qt6ct
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("SSH_AUTH_SOCK",       (os.getenv("XDG_RUNTIME_DIR") or "/run/user/1000") .. "/ssh-agent.socket")

-- Intel HD 520 fixes
hl.env("LIBVA_DRIVER_NAME",      "iHD")
hl.env("WLR_NO_HARDWARE_CURSORS","1")
