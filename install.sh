#!/usr/bin/env bash

script_dir=$(cd $(dirname $0); pwd)

mkdir -p ~/.config/fish
ln -s $script_dir/ansible/roles/fish/files/conf.d/* ~/.config/fish/conf.d/
ln -s $script_dir/ansible/roles/fish/files/functions/* ~/.config/fish/functions/

mkdir -p ~/.config/git
ln -s $script_dir/ansible/roles/git/files/.gitconfig ~/.gitconfig
ln -s $script_dir/ansible/roles/git/files/ignore ~/.config/git/ignore

