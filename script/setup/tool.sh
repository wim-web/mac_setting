#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$CURRENT_DIR/../.." && pwd)"

install_brew_list() {
    local package_kind="$1"
    local package_file="$2"
    local package

    while IFS= read -r package; do
        [[ -z "$package" || "$package" == \#* ]] && continue
        echo "> $package"
        if [[ "$package_kind" == 'formula' ]]; then
            if brew list --formula "$package" >/dev/null 2>&1; then
                echo "already installed"
            else
                echo "install $package"
                brew install "$package"
            fi
        else
            if brew list --cask "$package" >/dev/null 2>&1; then
                echo "already installed"
            else
                echo "install $package"
                brew install --cask "$package"
            fi
        fi
        echo ""
    done < "$package_file"
}

main() {
    # aqua
    if type aqua >/dev/null; then
        echo "aqua already installed"
    else
        echo "> aqua install"
        curl -sSfL https://raw.githubusercontent.com/aquaproj/aqua-installer/v4.0.5/aqua-installer | bash -s -- -v v2.60.1
        fish -c "set -Ux AQUA_GLOBAL_CONFIG ~/.config/aquaproj-aqua/aqua.yaml"
        fish -c "fish_add_path ~/.local/share/aquaproj-aqua/bin || :"
    fi

    if type fish >/dev/null 2>&1; then
        fish -c "fish_add_path ~/.local/bin || :"
    fi

    # brew
    install_brew_list 'formula' "$REPO_ROOT/config/brew-formulae.txt"

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

    install_brew_list 'cask' "$REPO_ROOT/config/brew-casks.txt"

    # docker compose
    "$CURRENT_DIR/../installer/docker-compose.sh"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
