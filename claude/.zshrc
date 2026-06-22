# shellcheck shell=bash
# Cyfrin Claude dev container shell configuration.

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.foundry/bin:$PATH"

# Never trust a forwarded host SSH agent inside the container (defense in depth;
# also set in devcontainer.json). Empty, not unset, to block fallback to default
# socket paths. Removing this re-enables host SSH auth for trusted work only.
export SSH_AUTH_SOCK=

# fnm (Node)
export FNM_DIR="$HOME/.fnm"
export PATH="$FNM_DIR:$PATH"
eval "$(fnm env --use-on-cd)"

# History (persisted via the /commandhistory volume on the mounted variant).
export HISTFILE=/commandhistory/.zsh_history
export HISTSIZE=200000
export SAVEHIST=200000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS HIST_VERIFY
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
setopt COMPLETE_IN_WORD ALWAYS_TO_END

# Aliases
alias fd=fdfind
alias sg=ast-grep
alias claude-yolo='claude --dangerously-skip-permissions'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'

# fzf (fd-backed)
export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fdfind --type d --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --info=inline'
eval "$(fzf --zsh)"
