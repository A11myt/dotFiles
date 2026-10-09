#!/usr/bin/env bash
# Dotfiles von A11myt – Installation auf frischem Arch
#   git clone git@github.com:A11myt/dotFiles.git ~/Workspace/Github/dotfiles
#   cd ~/Workspace/Github/dotfiles && ./install.sh [--packages] [--system]
set -euo pipefail
cd "$(dirname "$(realpath "$0")")"
REPO="$PWD"

STOW_PKGS=(hypr ags alacritty nvim rofi tmux swaync wlogout matugen scripts pacman zsh git bin)

log() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }

if [[ " $* " == *" --packages "* ]]; then
    log "Pakete aus offiziellen Repos"
    sudo pacman -S --needed - < packages/pkglist.txt
    if ! command -v yay >/dev/null; then
        log "yay bootstrappen"
        tmp=$(mktemp -d); git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    fi
    log "AUR-Pakete"
    yay -S --needed - < packages/aur.txt
    log "Flatpaks"
    xargs -r flatpak install -y flathub < packages/flatpak.txt
fi

log "Dotfiles verlinken (stow)"
command -v stow >/dev/null || sudo pacman -S --needed stow
stow --simulate --verbose=1 --target="$HOME" "${STOW_PKGS[@]}"   # bricht bei Konflikten ab
stow --target="$HOME" "${STOW_PKGS[@]}"

log "Secret-Check-Hook aktivieren"
git -C "$REPO" config core.hooksPath hooks

if [[ " $* " == *" --system "* ]]; then
    log "Systemdateien nach /etc (greetd/ReGreet, PAM, Timeshift)"
    sudo install -Dm644 system/greetd/config.toml          /etc/greetd/config.toml
    sudo install -Dm644 system/greetd/regreet.toml         /etc/greetd/regreet.toml
    sudo install -Dm644 system/greetd/hyprland-greeter.lua /etc/greetd/hyprland-greeter.lua
    sudo install -Dm644 system/pam.d/greetd                /etc/pam.d/greetd
    sudo install -Dm644 system/timeshift/timeshift.json    /etc/timeshift/timeshift.json
    sudo install -d -o "$USER" -g greeter -m 755 /var/lib/greeter-theme
    echo "   ⚠ timeshift.json enthält die UUID der alten Root-Partition → in Timeshift neu wählen"
    sudo systemctl enable greetd.service
    systemctl --user enable --now ssh-agent.socket
fi

log "Start-Farbschema erzeugen (bis ein Wallpaper gewählt wird)"
matugen color hex "#ff6a00" >/dev/null 2>&1 || echo "   matugen noch nicht installiert – später: matugen color hex '#ff6a00'"

log "Fertig. Neu einloggen. Wallpaper: SUPER+W"
