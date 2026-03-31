# My Dotfiles

Personal configuration files.

## Installation

```bash
# Run the installation script
./install.sh
```

The installation script will:
1. Install missing dependencies
2. Set up Oh My Zsh and Powerlevel10k
3. Install Zsh plugins
4. Set up Tmux Plugin Manager
5. Symlink all configuration files using GNU Stow
6. Configure Zsh as your default shell

### Installation Options

```bash
# Skip dependency installation (if already installed)
./install.sh --skip-deps

# Skip GNU Stow symlinking
./install.sh --skip-stow

## Manual Installation

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

### 1. Configure Powerlevel10k
```bash
# Run the configuration wizard
p10k configure
```

### 2. Install Tmux Plugins
```bash

Press Ctrl-a + I (capital i) to install plugins
```


### 3. Install a Nerd Font
For proper icon display in terminal and editor:
```bash
brew install --cask font-jetbrains-mono-nerd-font
```


# Add New Configuration

To add a new config, create a directory mirroring the path from `$HOME`:

```bash
# Example: adding config for "foo" that lives at ~/.config/foo/foo.conf
mkdir -p foo/.config/foo
mv ~/.config/foo/foo.conf foo/.config/foo/foo.conf

# Symlink it
stow foo

The directory name (e.g. `foo`) becomes the stow package name. Everything inside it is symlinked relative to `$HOME`.
