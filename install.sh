#!/usr/bin/env bash

script_dir=$(cd $(dirname $0); pwd)

function fish_install() {
    curl -sL https://raw.githubusercontent.com/microsoft/vscode-dev-containers/main/script-library/fish-debian.sh | sudo bash
    fish -c 'echo oh-my-fish/theme-bobthefish | fisher install'
}

function fish_config() {
    mkdir -p ~/.config/fish
    ln -s $script_dir/ansible/roles/fish/files/conf.d/* ~/.config/fish/conf.d/
    ln -s $script_dir/ansible/roles/fish/files/functions/* ~/.config/fish/functions/
}

function git_config() {
    mkdir -p ~/.config/git
    ln -s $script_dir/ansible/roles/git/files/.gitconfig ~/.gitconfig
    ln -s $script_dir/ansible/roles/git/files/ignore ~/.config/git/ignore
}

function aqua_install() {
    curl -sSfL https://raw.githubusercontent.com/aquaproj/aqua-installer/v1.1.2/aqua-installer | sudo bash -s -- -v v1.25.0 -i /usr/bin/aqua
    mkdir -p ~/.local/share/aquaproj-aqua/bin
    fish -c 'fish_add_path ~/.local/share/aquaproj-aqua/bin'
}

fish_install
fish_config
git_config
aqua_install



