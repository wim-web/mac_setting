#!/usr/bin/env bash
set -euo pipefail

# aqua
if type aqua >/dev/null; then
    echo "aqua already installed"
else
    echo "> aqua install"
    curl -sSfL https://raw.githubusercontent.com/aquaproj/aqua-installer/v2.0.0/aqua-installer | bash -s -- -v v1.30.0
    fish -c "set -Ux AQUA_GLOBAL_CONFIG ~/.config/aquaproj-aqua/aqua.yml"
    fish -c "fish_add_path ~/.local/share/aquaproj-aqua/bin || :"
fi

# brew
declare -a brew_packages=(
# renovate: datasource=github-tags depName=qemu/qemu
# QEMU_VERSION=7.1.0
    "qemu"
# renovate: datasource=github-tags depName=docker/cli
# QEMU_VERSION=20.10.17
    "docker"
# renovate: datasource=github-releases depName=twpayne/chezmoi
# QEMU_VERSION=2.29.0
    "chezmoi"
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
  "hyperswitch"
  "google-drive-file-stream"
  "keyboardcleantool"
  "appcleaner"
  "lunar"
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
# renovate: datasource=github-releases depName=docker/compose
DOCKER_COMPOSE_VERSION=2.14.0
docker_compose_dir="$HOME/.docker/cli-plugins"
docker_compose_name="docker-compose"

if [ -e "$docker_compose_dir/$docker_compose_name" ]; then
    echo "already installed docker-compose"
else
    mkdir -p "$docker_compose_dir"
    curl -sLo "$docker_compose_dir/$docker_compose_name" https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-darwin-aarch64
fi
