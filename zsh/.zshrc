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


# Uncomment to use the profiling module
# zmodload zsh/zprof

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"


# Don't clutter $HOME with completion dumps
export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST

ZSH_THEME="powerlevel10k/powerlevel10k"

# ZSH Plugins
#
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git 
  aliases 
  colored-man-pages 
  colorize 
  dircycle
  zsh-autosuggestions
  extract
  docker
  brew
  zsh-vi-mode
)

source $ZSH/oh-my-zsh.sh

# User configuration

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi



# ======================================================================================================================================================

export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"


# LANG
export LC_ALL=en_US.UTF-8

# aliases

alias ccat='pygmentize'
alias cat='bat -pp'  # Alias for cat, to bat, but only for coloring. 
alias zshreload='source ~/.zshrc'
alias zshconfig='$EDITOR ~/.zshrc'
alias myip='curl -s https://ipinfo.io/ip'
alias ls='eza'


# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ======================================================================================================================================================
#
# VIM mode
#
# Fixes Mac OS option + delete in insert mode
bindkey -M viins '\e^?' backward-kill-word

# ======================================================================================================================================================
#
# FZF CONFIGURATION
#
source <(fzf --zsh)

source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# FZF theme configuration

export FZF_DEFAULT_OPTS=" \
--color=bg+:#CCD0DA,spinner:#DC8A78,hl:#D20F39 \
--color=header:#D20F39,info:#8839EF,pointer:#DC8A78 \
--color=marker:#7287FD,fg+:#4C4F69,prompt:#8839EF,hl+:#D20F39 \
--color=selected-bg:#BCC0CC \
--color=border:#9CA0B0,label:#4C4F69 \
--walker file,hidden
"


# ======================================================================================================================================================
#
# DOCKER COMPLETIONS

# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=($HOME/.docker/completions $fpath)
autoload -Uz compinit

compinit

# ======================================================================================================================================================

# Better history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY



# Better completion
setopt AUTO_CD
setopt CORRECT
setopt MENU_COMPLETE

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'


# Fix fzf history search with zsh-vi-mode
function zvm_after_init() {
  # Restore fzf key bindings
  source <(fzf --zsh)
}

# ======================================================================================================================================================
# AUTO VIRTUALENV ACTIVATION/DEACTIVATION
# Automatically activates a Python virtual environment when you `cd` into a directory
#
# Function to find virtualenv in current or parent directories
_find_venv() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/venv/bin/activate" ]]; then
            echo "$dir/venv"
            return 0
        elif [[ -f "$dir/.venv/bin/activate" ]]; then
            echo "$dir/.venv"
            return 0
        elif [[ -f "$dir/env/bin/activate" ]]; then
            echo "$dir/env"
            return 0
        fi
        dir="$(dirname "$dir")"
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
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
