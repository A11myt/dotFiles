hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/bin/gnome-keyring-daemon --start --components=secrets,pkcs11")
    -- SSH-Key sofort laden: Passphrase aus dem Keyring (PAM-entsperrt), Fallback Zenity
    hl.exec_cmd("SSH_ASKPASS_REQUIRE=force SSH_ASKPASS=$HOME/.local/bin/ssh-askpass-keyring.sh setsid ssh-add $HOME/.ssh/id_ed25519 < /dev/null > /dev/null 2>&1")
    -- hl.exec_cmd("swaync >> ~/.logs/swaync.log 2>&1")  -- alt
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")  -- Root-Rechte-Dialoge für GUI-Apps
    hl.exec_cmd("hypridle >> ~/.logs/hypridle.log 2>&1")  -- Dim/Lock/DPMS/Suspend, reagiert auf loginctl lock-session
    hl.exec_cmd("ags run ~/.config/ags/app.ts >> ~/.logs/ags.log 2>&1")
    hl.exec_cmd("awww-daemon >> ~/.logs/awww.log 2>&1")
    -- zuletzt gewähltes Wallpaper (SUPER+W), Fallback TrainWallpaper
    hl.exec_cmd('sleep 1 && W=$(readlink -e ~/.cache/wallpaper-picker/current || echo ~/Pictures/wallpapers/TrainWallpaper.jpg); ~/.config/matugen/wallpaper.sh "$W" >> ~/.logs/awww.log 2>&1')
    -- zuletzt offene Programme wiederherstellen (einmal pro Login; nach Leiste/Wallpaper)
    hl.exec_cmd("sleep 3 && ~/.local/bin/session restore")
    -- Hyprland log symlink -> ~/.logs/hyprland.log
    hl.exec_cmd([[ln -sf "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log" ~/.logs/hyprland.log]])
end)
