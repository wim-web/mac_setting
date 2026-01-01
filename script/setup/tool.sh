#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$( cd "$( dirname "$0" )" && pwd )"

# aqua
if type aqua >/dev/null; then
    echo "aqua already installed"
else
    echo "> aqua install"
    curl -sSfL https://raw.githubusercontent.com/aquaproj/aqua-installer/v4.0.4/aqua-installer | bash -s -- -v v2.55.1
    fish -c "set -Ux AQUA_GLOBAL_CONFIG ~/.config/aquaproj-aqua/aqua.yaml"
    fish -c "fish_add_path ~/.local/share/aquaproj-aqua/bin || :"
fi

# brew
declare -a brew_packages=(
# renovate: datasource=github-tags depName=qemu/qemu
# VERSION=10.2.0
    "qemu"
# renovate: datasource=github-releases depName=twpayne/chezmoi
# VERSION=2.68.1
    "chezmoi"
# renovate: datasource=github-tags depName=git/git
# VERSION=2.52.0
    "git"
# renovate: datasource=github-tags depName=aws/aws-cli
# VERSION=2.32.26
    "awscli"
    
    "bluesnooze"
# renovate: datasource=github-tags depName=openai/codex extractVersion=^rust-v(?<version>.*)$
# VERSION=0.77.0
    "codex"
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
)

declare -r brew_taps="$(brew tap)"

if echo "$brew_taps" | grep -qx "microsoft/git"; then
        :
    else
        brew tap microsoft/git # for git-credential-manager
fi

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
