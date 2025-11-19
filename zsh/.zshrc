# Uncomment to use the profiling module
# zmodload zsh/zprof

# ====================================================================================================================================================== 
#
# POWERLEVEL10K CONFIGURATION
#
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Don't clutter $HOME with completion dumps
export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST

ZSH_THEME="powerlevel10k/powerlevel10k"

# ======================================================================================================================================================
#
# COMPLETION SETUP - MUST BE BEFORE OH-MY-ZSH

# Docker completions
fpath=($HOME/.docker/completions $fpath)

# Skip compinit during Oh-My-Zsh load - we'll do it ourselves (avoids double init)
skip_global_compinit=1

# ======================================================================================================================================================
#
# ZSH PLUGINS

plugins=(
  git 
  colored-man-pages 
  zsh-autosuggestions
  docker
  zsh-vi-mode
)

source $ZSH/oh-my-zsh.sh

# ======================================================================================================================================================
#
# OPTIMIZED COMPLETION INITIALIZATION

autoload -Uz compinit

# Only regenerate compdump once per day
# -C flag skips the security check (compaudit) for cached files
for dump in ${ZSH_COMPDUMP}(Nm+1); do
  compinit -d "$ZSH_COMPDUMP"
  break
done

compinit -C -d "$ZSH_COMPDUMP"

# ======================================================================================================================================================
#
# USER CONFIGURATION

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# LANG
export LC_ALL=en_US.UTF-8

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

# Initialize pyenv properly
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
fi

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

# PostgreSQL
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"

# ======================================================================================================================================================
#
# ALIASES
#

alias cat='bat -pp'
alias rcat='/bin/cat'
alias zshreload='source ~/.zshrc'
alias zshconfig='$EDITOR ~/.zshrc'
alias myip='curl -s https://ipinfo.io/ip'
alias ls='eza'
alias view='nvim -R'

# ======================================================================================================================================================
#
# HISTORY CONFIGURATION
#

HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY

# ======================================================================================================================================================
#
# COMPLETION SETTINGS
#

setopt AUTO_CD
setopt CORRECT
setopt MENU_COMPLETE

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# ======================================================================================================================================================
#
# VIM MODE
#

# Fixes Mac OS option + delete in insert mode
bindkey -M viins '\e^?' backward-kill-word

# ======================================================================================================================================================
#
# FZF CONFIGURATION
#

# FZF theme configuration
export FZF_DEFAULT_OPTS=" \
--color=bg+:#CCD0DA,spinner:#DC8A78,hl:#D20F39 \
--color=header:#D20F39,info:#8839EF,pointer:#DC8A78 \
--color=marker:#7287FD,fg+:#4C4F69,prompt:#8839EF,hl+:#D20F39 \
--color=selected-bg:#BCC0CC \
--color=border:#9CA0B0,label:#4C4F69 \
--walker file,hidden \
"

alias fzfp='fzf --preview="bat --style=numbers --color=always --line-range :500 {}"'

# Fix fzf history search with zsh-vi-mode
function zvm_after_init() {
  source <(fzf --zsh)
}

# ======================================================================================================================================================
#
# SYNTAX HIGHLIGHTING
#

source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ======================================================================================================================================================
#
# AUTO VIRTUALENV ACTIVATION/DEACTIVATION
#

# Function to find virtualenv in current or parent directories
_find_venv() {
    local dir="$PWD"
    local depth=0
    # Limit search depth to 3 levels max for performance
    while [[ "$dir" != "/" && $depth -lt 3 ]]; do
        for venv_dir in venv .venv env; do
            if [[ -f "$dir/$venv_dir/bin/activate" ]]; then
                echo "$dir/$venv_dir"
                return 0
            fi
        done
        dir="$(dirname "$dir")"
        ((depth++))
    done
    return 1
}

# Function to auto-activate/deactivate virtualenv
_auto_venv() {
    local venv_path=$(_find_venv)
    
    # If we found a venv and it's not the currently active one
    if [[ -n "$venv_path" ]]; then
        if [[ "$VIRTUAL_ENV" != "$venv_path" ]]; then
            # Deactivate current venv if one is active
            if [[ -n "$VIRTUAL_ENV" ]]; then
                deactivate
            fi
            # Activate the new venv
            source "$venv_path/bin/activate"
        fi
    # If no venv found but one is active, deactivate it
    elif [[ -n "$VIRTUAL_ENV" ]]; then
        deactivate
    fi
}

# Hook the function to directory changes
autoload -U add-zsh-hook
add-zsh-hook chpwd _auto_venv

# Run once when shell starts
_auto_venv

# ======================================================================================================================================================
#
# POWERLEVEL10K PROMPT

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ======================================================================================================================================================
# Uncomment to see profiling results
# zprof
