#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
formulae_file="$repo_root/config/brew-formulae.txt"
casks_file="$repo_root/config/brew-casks.txt"
tool_script="$repo_root/script/setup/tool.sh"

fail_test() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

package_lines() {
    grep -Ev '^[[:space:]]*(#|$)' "$1"
}

assert_sorted_unique() {
    local file="$1"
    local actual expected
    actual="$(package_lines "$file")"
    expected="$(printf '%s\n' "$actual" | LC_ALL=C sort -u)"
    [[ "$actual" == "$expected" ]] || fail_test "$file must be sorted and unique"
}

assert_package() {
    local file="$1"
    local package="$2"
    package_lines "$file" | grep -Fxq "$package" || fail_test "$package missing from $file"
}

test -f "$formulae_file"
test -f "$casks_file"
assert_sorted_unique "$formulae_file"
assert_sorted_unique "$casks_file"

[[ "$(package_lines "$formulae_file" | wc -l | tr -d ' ')" -eq 4 ]] || fail_test 'formula count must be 4'
[[ "$(package_lines "$casks_file" | wc -l | tr -d ' ')" -eq 21 ]] || fail_test 'cask count must be 21'

for package in bluesnooze chezmoi git qemu; do
    assert_package "$formulae_file" "$package"
done

for package in \
    1password alfred alt-tab appcleaner clipy codex docker fork \
    git-credential-manager google-chrome google-drive google-japanese-ime gostty \
    iterm2 keyboardcleantool obsidian slack spectacle tableplus visual-studio-code zoom; do
    assert_package "$casks_file" "$package"
done

grep -Fq 'config/brew-formulae.txt' "$tool_script"
grep -Fq 'config/brew-casks.txt' "$tool_script"
! grep -Fq 'brew_packages=(' "$tool_script"
! grep -Fq 'brew_cask_packages=(' "$tool_script"

printf 'setup list tests passed\n'
