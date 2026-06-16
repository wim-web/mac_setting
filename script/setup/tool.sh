#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$( cd "$( dirname "$0" )" && pwd )"

# aqua
if type aqua >/dev/null; then
    echo "aqua already installed"
else
    echo "> aqua install"
    curl -sSfL https://raw.githubusercontent.com/aquaproj/aqua-installer/v4.0.4/aqua-installer | bash -s -- -v v2.60.0
    fish -c "set -Ux AQUA_GLOBAL_CONFIG ~/.config/aquaproj-aqua/aqua.yaml"
    fish -c "fish_add_path ~/.local/share/aquaproj-aqua/bin || :"
fi

if type fish >/dev/null 2>&1; then
    fish -c "fish_add_path ~/.local/bin || :"
fi

# brew
declare -a brew_packages=(
# renovate: datasource=github-tags depName=qemu/qemu
# VERSION=11.0.1
    "qemu"
# renovate: datasource=github-releases depName=twpayne/chezmoi
# VERSION=2.70.5
    "chezmoi"
# renovate: datasource=github-tags depName=git/git
# VERSION=2.54.0
    "git"
    "bluesnooze"
)
declare -r installed_brew_packages="$(brew list -1 --formula)"

for package in "${brew_packages[@]}"; do
    echo "> $package"
    if echo "$installed_brew_packages" | grep -qx $package; then
        echo "already installed"
    else
        echo "install $package"
        brew install "$package"
    fi
    echo ""
done

# awscli
if type brew >/dev/null 2>&1 && brew list --versions awscli >/dev/null 2>&1; then
    echo "> awscli install"
    "$CURRENT_DIR/../installer/awscli.sh"
elif aws --version >/dev/null 2>&1; then
    echo "awscli already installed"
else
    echo "> awscli install"
    "$CURRENT_DIR/../installer/awscli.sh"
fi

declare -a brew_cask_packages=(
    "google-chrome"
    "clipy"
    "tableplus"
    "fork"
    "alfred"
    "obsidian"
    "slack"
    "spectacle"
    "iterm2"
    "visual-studio-code"
    "google-japanese-ime"
    "1password"
    "alt-tab"
    "google-drive"
    "keyboardcleantool"
    "appcleaner"
    "docker"
    "zoom"
    "git-credential-manager"
    "gostty"
    # renovate: datasource=github-tags depName=openai/codex extractVersion=^rust-v(?<version>.*)$
    # VERSION=0.128.0
    "codex"
)

declare -r installed_brew_cask_packages="$(brew list -1 --casks)"

for package in "${brew_cask_packages[@]}"; do
    echo "> $package"
    if echo "$installed_brew_cask_packages" | grep -qx $package; then
        echo "already installed"
    else
        echo "install $package"
        brew install --cask "$package"
    fi
    echo ""
done

# docker compose
$CURRENT_DIR/../installer/docker-compose.sh
