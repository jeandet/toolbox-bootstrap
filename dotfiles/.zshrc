# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# PATH — local bins first (toolchains persist in $HOME across toolbox resets)
export PATH="$HOME/.local/bin:$HOME/.roswell/bin:/usr/local/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin:$PATH"
export PATH="$HOME/.opencode/bin:$HOME/.kimi-code/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=powerlevel10k/powerlevel10k

plugins=(
  kubectl-autocomplete
  git uv firewalld docker thefuck
  zsh-syntax-highlighting zsh-autosuggestions
  rust zoxide fzf
  zsh-interactive-cd zsh-navigation-tools
  colored-man-pages command-not-found dnf extract isodate podman toolbox
)

source "$ZSH/oh-my-zsh.sh"

# p10k
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# aliases — lsd overrides colorls; bat for cat
alias ll='colorls -lA --sd --gs --group-directories-first 2>/dev/null || lsd -lA --group-dirs first'
alias ls='lsd --group-dirs first 2>/dev/null || ls --color=auto --group-directories-first'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'
alias cat='bat --theme=TwoDark 2>/dev/null || cat'
alias grep='grep --color=auto'
alias prog='cd ~/Documents/prog'
alias PCB='cd ~/Documents/PCB'
# proxy example — customize with your jump host
# alias proxy="ssh -C2qTnN -D 8080 user@jump-host"
alias fuck='TF_CMD=$(TF_ALIAS=fuck PYTHONIOENCODING=utf-8 TF_SHELL_ALIASES=$(alias) thefuck $(fc -ln -1)) && eval $TF_CMD; history -s $TF_CMD'
alias stm32cubeide='GDK_BACKEND=x11 /opt/st/stm32cubeide_1.1.0/stm32cubeide 2>/dev/null || echo "stm32cubeide not installed"'

# completions — guarded so toolbox without gem still starts
if command -v gem &>/dev/null && gem which colorls &>/dev/null; then
  source "$(dirname "$(gem which colorls)")/tab_complete.sh" 2>/dev/null || true
fi
[[ -f ~/.local/bin/elm-completion.sh ]] && source ~/.local/bin/elm-completion.sh

export NPM_PACKAGES="$HOME/.npm-packages"
PATH="$NPM_PACKAGES/bin:$PATH"
MANPATH="$NPM_PACKAGES/share/man:$(manpath 2>/dev/null || echo /usr/share/man)"
NODE_PATH="$NPM_PACKAGES/lib/node_modules:$NODE_PATH"

if (( ${+container} )); then
  alias podman='/usr/bin/podman --remote'
fi
