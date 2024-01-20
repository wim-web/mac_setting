#!/usr/bin/env zsh

# homebrew
# renovate: datasource=github-releases depName=Homebrew/brew
# HOMEBREW_VERSION=4.2.4
if type brew >/dev/null; then
    echo "Already installed homebrew"
else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    PATH=$PATH:/opt/homebrew/bin
fi

# fish shell
# renovate: datasource=github-tags depName=fish-shell/fish-shell
# FISH_VERSION=3.7.0
if brew list | grep fish >/dev/null; then
    echo "Already installed fish"
else
    brew install fish
    echo $(which fish) | sudo tee /etc/shells
    chsh -s $(which fish)
    fish -c "fish_add_path /opt/homebrew/bin"
fi

# font
fonts_path="$HOME/Library/Fonts/"
tmp_fonts_path="/tmp/hackgen.zip"
if ls "$fonts_path" | grep -q HackGen; then
    echo "already installed hackgen font"
else
    curl -sLo "$tmp_fonts_path" https://github.com/yuru7/HackGen/releases/download/v2.8.0/HackGen_NF_v2.8.0.zip
    unzip -jd "$fonts_path" "$tmp_fonts_path"
    rm "$tmp_fonts_path"
fi
