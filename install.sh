#!/usr/bin/env bash

# ==============================================================================
# Dotfiles Installation Script
# ==============================================================================
# This script installs dotfiles and their dependencies on macOS/Linux.
# Usage: ./install.sh [OPTIONS]
#
# Options:
#   --help              Show this help message
#   --skip-deps         Skip dependency installation
#   --skip-stow         Skip GNU Stow symlinking
#   --only PACKAGE      Only install specific package (e.g., --only zsh)
# ==============================================================================

set -e # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKIP_DEPS=false
SKIP_STOW=false
ONLY_PACKAGE=""

# ==============================================================================
# Helper Functions
# ==============================================================================

print_header() {
  echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"
}

print_info() {
  echo -e "${BLUE}==>${NC} $1"
}

print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}!${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ==============================================================================
# Parse Arguments
# ==============================================================================

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    --help)
      cat <<'EOF'
Dotfiles Installation Script
=============================
This script installs dotfiles and their dependencies on macOS/Linux.

Usage: ./install.sh [OPTIONS]

Options:
  --help              Show this help message
  --skip-deps         Skip dependency installation
  --skip-stow         Skip GNU Stow symlinking
  --only PACKAGE      Only install specific package (e.g., --only zsh)

Examples:
  ./install.sh                    # Full installation
  ./install.sh --skip-deps        # Skip dependency installation
  ./install.sh --only zsh         # Only install zsh configs
EOF
      exit 0
      ;;
    --skip-deps)
      SKIP_DEPS=true
      shift
      ;;
    --skip-stow)
      SKIP_STOW=true
      shift
      ;;
    --only)
      ONLY_PACKAGE="$2"
      shift 2
      ;;
    *)
      print_error "Unknown option: $1"
      exit 1
      ;;
    esac
  done
}

# ==============================================================================
# System Detection
# ==============================================================================

detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "linux"
  else
    echo "unknown"
  fi
}

# ==============================================================================
# Dependency Installation
# ==============================================================================

install_homebrew() {
  if ! command_exists brew; then
    print_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    print_success "Homebrew installed"
  else
    print_success "Homebrew already installed"
  fi
}

install_stow() {
  if ! command_exists stow; then
    print_info "Installing GNU Stow..."
    if [[ $(detect_os) == "macos" ]]; then
      brew install stow
    elif [[ $(detect_os) == "linux" ]]; then
      if command_exists apt-get; then
        sudo apt-get install -y stow
      elif command_exists dnf; then
        sudo dnf install -y stow
      elif command_exists pacman; then
        sudo pacman -S --noconfirm stow
      fi
    fi
    print_success "GNU Stow installed"
  else
    print_success "GNU Stow already installed"
  fi
}

install_homebrew_packages() {
  print_info "Installing Homebrew packages..."

  local packages=(
    "bat"    # Better cat
    "eza"    # Better ls
    "fzf"    # Fuzzy finder
    "tmux"   # Terminal multiplexer
    "neovim" # Editor
    "zsh-syntax-highlighting"
  )

  for package in "${packages[@]}"; do
    if brew list "$package" &>/dev/null; then
      print_success "$package already installed"
    else
      print_info "Installing $package..."
      brew install "$package"
      print_success "$package installed"
    fi
  done
}

install_oh_my_zsh() {
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    print_info "Installing Oh My Zsh..."
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    print_success "Oh My Zsh installed"
  else
    print_success "Oh My Zsh already installed"
  fi
}

install_powerlevel10k() {
  local p10k_dir="$HOME/powerlevel10k"
  if [[ ! -d "$p10k_dir" ]]; then
    print_info "Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
    print_success "Powerlevel10k installed"
  else
    print_success "Powerlevel10k already installed"
  fi
}

install_zsh_plugins() {
  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  # zsh-autosuggestions
  if [[ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]]; then
    print_info "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions"
    print_success "zsh-autosuggestions installed"
  else
    print_success "zsh-autosuggestions already installed"
  fi

  # zsh-vi-mode
  if [[ ! -d "$zsh_custom/plugins/zsh-vi-mode" ]]; then
    print_info "Installing zsh-vi-mode..."
    git clone https://github.com/jeffreytse/zsh-vi-mode "$zsh_custom/plugins/zsh-vi-mode"
    print_success "zsh-vi-mode installed"
  else
    print_success "zsh-vi-mode already installed"
  fi
}

install_tmux_plugin_manager() {
  local tpm_dir="$HOME/.tmux/plugins/tpm"
  if [[ ! -d "$tpm_dir" ]]; then
    print_info "Installing Tmux Plugin Manager..."
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
    print_success "TPM installed"
    print_info "Run 'tmux' and press 'prefix + I' to install tmux plugins"
  else
    print_success "TPM already installed"
  fi
}

install_pyenv() {
  if ! command_exists pyenv; then
    print_info "Installing pyenv..."
    if [[ $(detect_os) == "macos" ]]; then
      brew install pyenv
    else
      curl https://pyenv.run | bash
    fi
    print_success "pyenv installed"
  else
    print_success "pyenv already installed"
  fi
}

# ==============================================================================
# Stow Configuration Files
# ==============================================================================

stow_packages() {
  cd "$SCRIPT_DIR"

  local packages=()
  if [[ -n "$ONLY_PACKAGE" ]]; then
    if [[ -d "$ONLY_PACKAGE" ]]; then
      packages=("$ONLY_PACKAGE")
    else
      print_error "Package '$ONLY_PACKAGE' not found"
      exit 1
    fi
  else
    # Get all directories except hidden ones
    for dir in */; do
      if [[ -d "$dir" ]]; then
        packages+=("${dir%/}")
      fi
    done
  fi

  print_info "Stowing configuration files..."

  for package in "${packages[@]}"; do
    if [[ -d "$package" ]]; then
      print_info "Stowing $package..."
      stow -v "$package" 2>&1 | grep -v "BUG in find_stowed_path" || true
      print_success "$package stowed"
    fi
  done
}

# ==============================================================================
# Post-installation Tasks
# ==============================================================================

post_install() {
  print_header "Post-installation tasks"

  # Change default shell to zsh if not already
  if [[ "$SHELL" != *"zsh"* ]]; then
    print_info "Changing default shell to zsh..."
    if command_exists zsh; then
      local zsh_path
      zsh_path=$(which zsh)
      if ! grep -q "$zsh_path" /etc/shells; then
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
      fi
      chsh -s "$zsh_path"
      print_success "Default shell changed to zsh"
      print_warning "Please log out and log back in for changes to take effect"
    fi
  else
    print_success "Default shell is already zsh"
  fi

  # Recommend font installation
  print_info ""
  print_warning "Recommended: Install a Nerd Font for terminal icons"
  print_info "Visit: https://www.nerdfonts.com/"
  print_info "Or install via Homebrew: brew install --cask font-jetbrains-mono-nerd-font"
}

# ==============================================================================
# Main Installation Flow
# ==============================================================================

main() {
  parse_args "$@"

  print_header "Dotfiles Installation"
  print_info "Installing to: $HOME"
  print_info "From: $SCRIPT_DIR"
  echo ""

  local os
  os=$(detect_os)
  print_info "Detected OS: $os"

  if [[ "$os" == "unknown" ]]; then
    print_error "Unsupported operating system"
    exit 1
  fi

  # Install dependencies
  if [[ "$SKIP_DEPS" == false ]]; then
    print_header "Installing dependencies"

    if [[ "$os" == "macos" ]]; then
      install_homebrew
      install_homebrew_packages
    fi

    install_stow
    install_oh_my_zsh
    install_powerlevel10k
    install_zsh_plugins
    install_tmux_plugin_manager
    install_pyenv
  else
    print_warning "Skipping dependency installation"
  fi

  # Stow dotfiles
  if [[ "$SKIP_STOW" == false ]]; then
    print_header "Symlinking dotfiles"
    stow_packages
  else
    print_warning "Skipping GNU Stow symlinking"
  fi

  # Post-installation
  post_install

  # Done
  print_header "Installation complete!"
  print_success "Your dotfiles have been installed"
  echo ""
  print_info "Next steps:"
  print_info "1. Restart your terminal or run: exec zsh"
  print_info "2. Configure Powerlevel10k: p10k configure"
  print_info "3. Open tmux and press 'Ctrl-a + I' to install plugins"
  print_info "4. Open nvim and let plugins install automatically"
  echo ""
}

main "$@"
