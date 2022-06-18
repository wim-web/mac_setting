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

fish_install
fish_config
git_config



