#!/bin/sh

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
ZSH_CUSTOM_DIR="$HOME/.oh-my-zsh/custom"
KITTY_CONFIG_DIR="$HOME/.config/kitty"
NVIM_CONFIG_DIR="$HOME/.config/nvim"

# Initialize git submodules (themes, plugins)
git -C "$DOTFILES_DIR" submodule update --init --recursive

# Ask for project folder
printf "Enter the project folder path for Kitty startup: "
read PROJECT_DIR
if [ -z "$PROJECT_DIR" ]; then
    echo "No project folder specified, skipping Kitty startup config."
else
    sed "s|__PROJECT_DIR__|$PROJECT_DIR|g" "$DOTFILES_DIR/kitty/startup.conf.template" > "$DOTFILES_DIR/kitty/startup.conf"
    echo "Set Kitty startup directory to $PROJECT_DIR"
fi

# Remove existing custom directory or symlink
if [ -L "$ZSH_CUSTOM_DIR" ]; then
    rm "$ZSH_CUSTOM_DIR"
elif [ -d "$ZSH_CUSTOM_DIR" ]; then
    echo "Backing up existing custom directory to ${ZSH_CUSTOM_DIR}.bak"
    mv "$ZSH_CUSTOM_DIR" "${ZSH_CUSTOM_DIR}.bak"
fi

ln -s "$DOTFILES_DIR/custom" "$ZSH_CUSTOM_DIR"
echo "Symlinked $DOTFILES_DIR/custom -> $ZSH_CUSTOM_DIR"

# Symlink kitty config
if [ -L "$KITTY_CONFIG_DIR" ]; then
    rm "$KITTY_CONFIG_DIR"
elif [ -d "$KITTY_CONFIG_DIR" ]; then
    echo "Backing up existing kitty config to ${KITTY_CONFIG_DIR}.bak"
    mv "$KITTY_CONFIG_DIR" "${KITTY_CONFIG_DIR}.bak"
fi

ln -s "$DOTFILES_DIR/kitty" "$KITTY_CONFIG_DIR"
echo "Symlinked $DOTFILES_DIR/kitty -> $KITTY_CONFIG_DIR"

# Helpers: install a brew formula if its command isn't on PATH; install a cask if not in `brew list --cask`.
brew_install_cmd() {
    cmd="$1"; formula="${2:-$1}"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "$cmd is already installed."
    else
        echo "Installing $formula..."
        brew install "$formula"
    fi
}

brew_install_cask() {
    cask="$1"
    if brew list --cask --versions "$cask" >/dev/null 2>&1; then
        echo "$cask is already installed."
    else
        echo "Installing $cask..."
        brew install --cask "$cask"
    fi
}

# CLI tools — command-name:formula pairs (use the same name when they match).
brew_install_cmd nvim neovim
brew_install_cmd fzf
brew_install_cmd rg ripgrep
brew_install_cmd lazygit
brew_install_cmd zoxide
brew_install_cmd eza
brew_install_cmd oh-my-posh jandedobbeleer/oh-my-posh/oh-my-posh

# Fonts
brew_install_cask font-jetbrains-mono-nerd-font

# Optionally patch ~/.zshrc to initialize oh-my-posh
OMP_INIT_LINE='eval "$(oh-my-posh init zsh --config ~/dotfiles/ohmyposh/config.omp.json)"'
if grep -Fxq "$OMP_INIT_LINE" "$HOME/.zshrc" 2>/dev/null; then
    echo "oh-my-posh init line already present in ~/.zshrc."
else
    printf "Patch ~/.zshrc with '%s'? [y/N]: " "$OMP_INIT_LINE"
    read PATCH_ZSHRC
    case "$PATCH_ZSHRC" in
        [yY]|[yY][eE][sS])
            printf '\n%s\n' "$OMP_INIT_LINE" >> "$HOME/.zshrc"
            echo "Appended oh-my-posh init to ~/.zshrc."
            ;;
        *)
            echo "Skipped patching ~/.zshrc."
            ;;
    esac
fi

# Symlink nvim config
if [ -L "$NVIM_CONFIG_DIR" ]; then
    rm "$NVIM_CONFIG_DIR"
elif [ -d "$NVIM_CONFIG_DIR" ]; then
    echo "Backing up existing nvim config to ${NVIM_CONFIG_DIR}.bak"
    mv "$NVIM_CONFIG_DIR" "${NVIM_CONFIG_DIR}.bak"
fi

ln -s "$DOTFILES_DIR/nvim" "$NVIM_CONFIG_DIR"
echo "Symlinked $DOTFILES_DIR/nvim -> $NVIM_CONFIG_DIR"