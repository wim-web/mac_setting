#!/usr/bin/env bash

script_dir=$(cd $(dirname $0); pwd)

function fish_install() {
    sudo apt-get update
    sudo apt-get -y install --no-install-recommends fish

    fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && echo jorgebucaran/fisher | fisher install"
    fish -c "echo oh-my-fish/theme-bobthefish | fisher install "
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



