#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
codex_config="$repo_root/.codex/config.toml"
expected_path='/Users/wim/.local/bin:/Users/wim/.cargo/bin:/Users/wim/.local/share/aquaproj-aqua/bin:/opt/homebrew/bin:/opt/homebrew/opt/mise/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin'

fail_test() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

test -f "$codex_config" || fail_test 'project Codex config missing'
grep -Fq '[shell_environment_policy]' "$codex_config" \
    || fail_test 'shell environment policy missing'
grep -Fq 'inherit = "core"' "$codex_config" \
    || fail_test 'Codex subprocess environment must use core inheritance'
grep -Fq "PATH = \"$expected_path\"" "$codex_config" \
    || fail_test 'Codex project PATH does not match the managed tool order'
grep -Fq 'ignore_default_excludes = false' "$codex_config" \
    || fail_test 'default secret-name exclusions must remain enabled'

printf 'codex project config tests passed\n'
