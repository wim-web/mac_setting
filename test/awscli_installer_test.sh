#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
installer="$repo_root/script/installer/awscli.sh"

fail_test() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

grep -Fq 'set -euo pipefail' "$installer" || fail_test 'strict mode missing'
grep -Fq 'mktemp -d' "$installer" || fail_test 'safe temporary directory missing'
grep -Fq "trap 'rm -rf \"\$temp_dir\"' EXIT" "$installer" \
    || fail_test 'temporary cleanup trap missing'
! grep -Fq 'pkg_path="/tmp/' "$installer" \
    || fail_test 'predictable package path remains'
! grep -Fq 'choices_path="/tmp/' "$installer" \
    || fail_test 'predictable choices path remains'

printf 'awscli installer tests passed\n'
