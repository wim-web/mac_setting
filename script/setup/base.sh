#!/usr/bin/env zsh
set -euo pipefail

# homebrew
# renovate: datasource=github-releases depName=Homebrew/brew
# HOMEBREW_VERSION=6.0.9
if command -v brew >/dev/null 2>&1; then
    echo "Already installed homebrew"
else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    export PATH="/opt/homebrew/bin:$PATH"
fi

# fish shell
# renovate: datasource=github-tags depName=fish-shell/fish-shell
# FISH_VERSION=4.8.1
if brew list --formula fish >/dev/null 2>&1; then
    echo "Already installed fish"
else
    brew install fish
fi

fish_path="$(command -v fish)"
if ! grep -Fxq "$fish_path" /etc/shells; then
    printf '%s\n' "$fish_path" | sudo tee -a /etc/shells >/dev/null
fi
current_user="$(id -un)"
configured_shell=''
if shell_record="$(dscl . -read "/Users/$current_user" UserShell 2>/dev/null)"; then
    configured_shell="${shell_record#UserShell: }"
fi
if [[ "$configured_shell" != "$fish_path" ]]; then
    chsh -s "$fish_path"
fi
fish -c "fish_add_path /opt/homebrew/bin"

# font
fonts_path="$HOME/Library/Fonts"
mkdir -p "$fonts_path"
if find "$fonts_path" -maxdepth 1 -iname '*HackGen*' -print -quit | grep -q .; then
    echo "already installed hackgen font"
else
    tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/mac-setting-fonts.XXXXXX")"
    trap 'rm -rf "$tmp_dir"' EXIT
    font_archive="$tmp_dir/hackgen.zip"
    curl -fsSL --retry 3 \
        -o "$font_archive" \
        https://github.com/yuru7/HackGen/releases/download/v2.8.0/HackGen_NF_v2.8.0.zip
    unzip -j -d "$fonts_path" "$font_archive"
fi
