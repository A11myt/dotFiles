#!/usr/bin/env bash
# $SSH_ASKPASS für ssh-add: Passphrase aus dem GNOME-Keyring, Fallback Zenity-Prompt.
# Einmalig hinterlegen:  secret-tool store --label="SSH id_ed25519" ssh-key ~/.ssh/id_ed25519
# ssh-add übergibt als $1 z.B. "Enter passphrase for /home/jason/.ssh/id_ed25519: "
#
# Schutz gegen Endlosschleife: ssh-add fragt bei falscher Passphrase immer wieder.
# Zweiter Aufruf für denselben Key innerhalb von 30 s → Keyring-Wert war falsch → Zenity.
# Leere Eingabe/Abbruch in Zenity beendet ssh-add.
LOG_TOOL=ssh-askpass source "$HOME/.config/scripts/log.sh"

key="$(sed -n 's/^Enter passphrase for \(.*\): *$/\1/p' <<<"$1")"
key="${key:-$HOME/.ssh/id_ed25519}"
marker="${XDG_RUNTIME_DIR:-/tmp}/ssh-askpass-$(printf '%s' "$key" | md5sum | cut -c1-8)"

if [[ -f "$marker" ]] && (( $(date +%s) - $(stat -c %Y "$marker") < 30 )); then
    rm -f "$marker"
    log_warn "keyring passphrase for $key rejected by ssh-add – asking via zenity"
    zenity --password --title="SSH-Key Passphrase (Keyring-Eintrag falsch)" || true
    exit 0
fi

if secret-tool lookup ssh-key "$key" 2>/dev/null; then
    touch "$marker"
    exit 0
fi

zenity --password --title="SSH-Key Passphrase" || true
