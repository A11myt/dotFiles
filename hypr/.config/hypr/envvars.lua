hl.env("XCURSOR_SIZE",        "24")
hl.env("HYPRCURSOR_SIZE",     "24")
hl.env("GDK_SCALE",           "1")
hl.env("QT_SCALE_FACTOR",     "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")  -- Qt5 → qt5ct, Qt6 → qt6ct (das Plugin hört auch auf "qt5ct"); Matugen-Palette
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
-- eigene Tools (wallthemes, dotdoctor) für Keybinds; nur einmal voranstellen (reload läuft oft)
do
    local bin, path = os.getenv("HOME") .. "/.local/bin", os.getenv("PATH") or "/usr/bin"
    if not (":" .. path .. ":"):find(":" .. bin .. ":", 1, true) then
        hl.env("PATH", bin .. ":" .. path)
    end
end
hl.env("SSH_AUTH_SOCK",       (os.getenv("XDG_RUNTIME_DIR") or "/run/user/1000") .. "/ssh-agent.socket")

-- Intel HD 520 fixes
hl.env("LIBVA_DRIVER_NAME",      "iHD")
hl.env("WLR_NO_HARDWARE_CURSORS","1")
