-- Dauerprozesse über logrun: Ausgabe nach ~/.logs/<name>.log, über 1 MB → <name>.log.1 (wächst nicht unbegrenzt)
hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/bin/gnome-keyring-daemon --start --components=secrets,pkcs11")
    -- SSH-Key sofort laden: Passphrase aus dem Keyring (PAM-entsperrt), Fallback Zenity
    hl.exec_cmd("SSH_ASKPASS_REQUIRE=force SSH_ASKPASS=$HOME/.local/bin/ssh-askpass-keyring.sh setsid ssh-add $HOME/.ssh/id_ed25519 < /dev/null > /dev/null 2>&1")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")  -- Root-Rechte-Dialoge für GUI-Apps
    hl.exec_cmd("~/.local/bin/logrun hypridle hypridle")  -- Dim/Lock/DPMS/Suspend, reagiert auf loginctl lock-session
    hl.exec_cmd("~/.local/bin/logrun quickshell qs")   -- Oberfläche (Quickshell; AGS-Stand: git tag ags-final)
    hl.exec_cmd("~/.local/bin/logrun awww awww-daemon")
    -- Zwischenablage-Verlauf: Text und Bilder an cliphist (SUPER+SHIFT+V)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    -- zuletzt gewähltes Wallpaper (SUPER+W), Fallback TrainWallpaper
    hl.exec_cmd('sleep 1 && W=$(readlink -e ~/.cache/wallpaper-picker/current || echo ~/Pictures/wallpapers/TrainWallpaper.jpg); ~/.config/matugen/wallpaper.sh "$W" >> ~/.logs/awww.log 2>&1')
    -- zuletzt offene Programme wiederherstellen (einmal pro Login; nach Leiste/Wallpaper)
    hl.exec_cmd("sleep 3 && ~/.local/bin/session restore")
    -- Hyprland log symlink -> ~/.logs/hyprland.log
    hl.exec_cmd([[ln -sf "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log" ~/.logs/hyprland.log]])
end)
