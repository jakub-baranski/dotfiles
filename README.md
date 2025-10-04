# My Dotfiles

Personal configuration files for a modern, productive development environment.

## What's Included

- **[Zsh](https://www.zsh.org/)** - Modern shell with powerful features
- **[Neovim](https://neovim.io/)** - Hyperextensible Vim-based text editor (LazyVim)
- **[Tmux](https://github.com/tmux/tmux)** - Terminal multiplexer
- **[Ghostty](https://ghostty.org/)** - Fast, feature-rich terminal emulator

## 📦 Prerequisites

### Required
- [Git](https://git-scm.com/)
- [Zsh](https://www.zsh.org/) (pre-installed on macOS)

### Optional (will be installed by script)
- [Homebrew](https://brew.sh/) (macOS)
- [GNU Stow](https://www.gnu.org/software/stow/)
- [Oh My Zsh](https://ohmyz.sh/)
- Various CLI tools (bat, eza, fzf, etc.)

## 🚀 Quick Installation

```bash
# Clone this repository
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Run the installation script
./install.sh
```

The installation script will:
1. ✅ Install missing dependencies
2. ✅ Set up Oh My Zsh and Powerlevel10k
3. ✅ Install Zsh plugins
4. ✅ Set up Tmux Plugin Manager
5. ✅ Symlink all configuration files using GNU Stow
6. ✅ Configure Zsh as your default shell

### Installation Options

```bash
# Show help
./install.sh --help

# Skip dependency installation (if already installed)
./install.sh --skip-deps

# Skip GNU Stow symlinking
./install.sh --skip-stow

# Install only specific package
./install.sh --only zsh
```

## 📝 Manual Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Install GNU Stow
brew install stow  # macOS
# or
sudo apt-get install stow  # Ubuntu/Debian

# Install all configs
stow */

# Or install individually
stow zsh
stow nvim
stow tmux
stow ghostty
```

## 🔧 Post-Installation

### 1. Configure Powerlevel10k
```bash
# Run the configuration wizard
p10k configure
```

### 2. Install Tmux Plugins
```bash
# Start tmux
tmux

# Press Ctrl-a + I (capital i) to install plugins
```

### 3. Set Up Neovim
```bash
# Open Neovim - plugins will install automatically
nvim
```

### 4. Install a Nerd Font
For proper icon display in terminal and editor:
```bash
# Using Homebrew (macOS)
brew install --cask font-jetbrains-mono-nerd-font

# Or download manually from:
# https://www.nerdfonts.com/
```

## 🎨 Customization

### Changing Themes

**Neovim:**
Edit `nvim/.config/nvim/lua/plugins/theme.lua`

**Ghostty:**
Edit `ghostty/.config/ghostty/config` - change the `theme` line

**Zsh:**
Run `p10k configure` to customize your prompt

### Adding Your Own Configs

```bash
# Create a new config directory
mkdir -p myconfig/.config/myapp

# Add your config files
cp ~/.config/myapp/config myconfig/.config/myapp/

# Stow it
stow myconfig
```
