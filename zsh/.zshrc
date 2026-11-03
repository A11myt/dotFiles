# Powerlevel10k Instant Prompt – muss ganz oben bleiben (alles mit Eingabe/Passwort darüber).
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ── Oh My Zsh ────────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# ── Prompt ───────────────────────────────────────────────────────────────────
# eigene Anpassung: `p10k configure` oder ~/.p10k.zsh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
# Prompt aus Theme Studio (Ergänzung; fehlt die Datei, bleibt ~/.p10k.zsh unverändert)
[[ ! -f ~/.config/theme-studio/p10k.zsh ]] || source ~/.config/theme-studio/p10k.zsh

# ── Werkzeuge ────────────────────────────────────────────────────────────────
# nvm erst beim ersten Aufruf laden (spart ~1 s pro Terminal).
# Die Default-Node-Version liegt trotzdem sofort im PATH (node/npm, Mason-LSPs in nvim).
export NVM_DIR="$HOME/.nvm"
() {
  local -a v=( $NVM_DIR/versions/node/v${$(<$NVM_DIR/alias/default 2>/dev/null)#v}*(N/nOn) )
  (( $#v )) && path=($v[1]/bin $path)
}
nvm() { unfunction nvm; source /usr/share/nvm/init-nvm.sh; nvm "$@" }

[[ -f "$HOME/.deno/env" ]] && . "$HOME/.deno/env"
export FLYCTL_INSTALL="$HOME/.fly"           # flyctl (Fly.io CLI), seit 2026-09-22
path=(
  $HOME/.local/bin                           # eigene Skripte (dotfiles/bin)
  $HOME/.cargo/bin                           # Rust (rustup), seit 2026-11-03
  $FLYCTL_INSTALL/bin
  $path
  $HOME/flutter/bin
)
typeset -U path                              # doppelte Einträge raus

# ── Aliase ───────────────────────────────────────────────────────────────────
alias jrun='./gradlew build -q && java -cp app/build/classes/java/main'
alias qs-restart='qs kill; setsid -f ~/.local/bin/logrun quickshell qs'   # Oberfläche neu starten
