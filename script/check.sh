#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

bash test/doctor_test.sh
bash test/setup_lists_test.sh
bash test/base_setup_test.sh
bash test/check_entrypoint_test.sh

while IFS= read -r script_path; do
    bash -n "$script_path"
done < <(find script test -type f -name '*.sh' | LC_ALL=C sort)

zsh -n script/setup/base.sh

printf 'all checks passed\n'
