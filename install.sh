#!/bin/sh

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
ZSH_CUSTOM_DIR="$HOME/.oh-my-zsh/custom"
KITTY_CONFIG_DIR="$HOME/.config/kitty"
NVIM_CONFIG_DIR="$HOME/.config/nvim"

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

# Install neovim if not already installed
if ! command -v nvim >/dev/null 2>&1; then
    echo "Installing neovim..."
    brew install neovim
else
    echo "neovim is already installed."
fi

# Install fzf and ripgrep for fuzzy finding in nvim
for pkg in fzf ripgrep lazygit; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
        echo "Installing $pkg..."
        brew install "$pkg"
    else
        echo "$pkg is already installed."
    fi
done

# Install JetBrains Mono Nerd Font
brew install --cask font-jetbrains-mono-nerd-font

# Symlink nvim config
if [ -L "$NVIM_CONFIG_DIR" ]; then
    rm "$NVIM_CONFIG_DIR"
elif [ -d "$NVIM_CONFIG_DIR" ]; then
    echo "Backing up existing nvim config to ${NVIM_CONFIG_DIR}.bak"
    mv "$NVIM_CONFIG_DIR" "${NVIM_CONFIG_DIR}.bak"
fi

ln -s "$DOTFILES_DIR/nvim" "$NVIM_CONFIG_DIR"
echo "Symlinked $DOTFILES_DIR/nvim -> $NVIM_CONFIG_DIR"