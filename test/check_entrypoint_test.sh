#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
check_script="$repo_root/script/check.sh"
workflow="$repo_root/.github/workflows/check.yml"

test -f "$check_script"
grep -Fq 'test/doctor_test.sh' "$check_script"
grep -Fq 'test/setup_lists_test.sh' "$check_script"
grep -Fq 'test/base_setup_test.sh' "$check_script"
grep -Fq 'bash -n' "$check_script"
grep -Fq 'zsh -n script/setup/base.sh' "$check_script"
grep -Fq 'persist-credentials: false' "$workflow"

printf 'check entrypoint tests passed\n'
