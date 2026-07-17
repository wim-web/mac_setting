#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
base_script="$repo_root/script/setup/base.sh"

fail_test() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

grep -Fq 'set -euo pipefail' "$base_script" || fail_test 'strict mode missing'
grep -Fq 'mktemp -d' "$base_script" || fail_test 'safe temporary directory missing'
grep -Fq "trap 'rm -rf \"\$tmp_dir\"' EXIT" "$base_script" || fail_test 'temporary cleanup trap missing'
grep -Fq 'command -v brew' "$base_script" || fail_test 'brew lookup must use command -v'
grep -Fq 'command -v fish' "$base_script" || fail_test 'fish lookup must use command -v'
grep -Fq 'sudo tee -a /etc/shells' "$base_script" || fail_test '/etc/shells must be appended, not overwritten'
! grep -Fq '/tmp/hackgen.zip' "$base_script" || fail_test 'shared temporary archive remains'
! grep -Eq 'echo[[:space:]]+\$\(which fish\)' "$base_script" || fail_test 'unquoted fish path remains'

printf 'base setup tests passed\n'
