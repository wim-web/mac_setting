#!/usr/bin/env bash
set -euo pipefail

# aqua
if type aqua >/dev/null; then
    # todo: renovate
    declare -r latest_aqua_version=1.30.2
    installed_aqua_version=$(aqua -v | grep -o -E "\d+\.\d+\.\d")
    echo "aqua => installed: $installed_aqua_version, latest: $latest_aqua_version"
    if [ "$installed_aqua_version" != "$latest_aqua_version" ]; then
        # update
        curl -sSfL https://raw.githubusercontent.com/aquaproj/aqua-installer/v2.0.2/aqua-installer | bash
    fi
else
    # install
    curl -sSfL https://raw.githubusercontent.com/aquaproj/aqua-installer/v2.0.2/aqua-installer | bash
    fish -c "set -Ux AQUA_GLOBAL_CONFIG ~/.config/aquaproj-aqua/aqua.yml"
    fish -c "fish_add_path ~/.local/share/aquaproj-aqua/bin || :"
fi

# brew
declare -a brew_packages=(
    "qemu"
    "docker"
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
docker_compose_dir="$HOME/.docker/cli-plugins"
docker_compose_name="docker-compose"

if [ -e "$docker_compose_dir/$docker_compose_name" ]; then
    echo "already installed docker-compose"
else
    mkdir -p "$docker_compose_dir"
    curl -sLo "$docker_compose_dir/$docker_compose_name" https://github.com/docker/compose/releases/download/v2.15.0/docker-compose-darwin-aarch64
fi
