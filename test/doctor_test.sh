#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
doctor="$repo_root/script/doctor.sh"
fixture_manifest="$repo_root/test/fixtures/toolchain-ok.tsv"
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

fixture_home="$fixture_root/home"
primary_bin="$fixture_home/bin"
secondary_bin="$fixture_home/other-bin"
mkdir -p "$primary_bin" "$secondary_bin"

fail_test() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local expected="$1"
    local actual="$2"
    [[ "$actual" == *"$expected"* ]] || fail_test "missing output: $expected"
}

assert_not_contains() {
    local unexpected="$1"
    local actual="$2"
    [[ "$actual" != *"$unexpected"* ]] || fail_test "unexpected output: $unexpected"
}

make_mock() {
    local directory="$1"
    local command_name="$2"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$directory/$command_name"
    chmod +x "$directory/$command_name"
}

make_output_mock() {
    local directory="$1"
    local command_name="$2"
    local output="$3"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" %q\n' "$output" > "$directory/$command_name"
    chmod +x "$directory/$command_name"
}

run_doctor() {
    local test_path="$1"
    run_doctor_with_manifest "$test_path" "$fixture_manifest"
}

run_doctor_with_manifest() {
    local test_path="$1"
    local manifest="$2"
    PATH="$test_path:/usr/bin:/bin" \
        DOCTOR_PATH="$test_path:/usr/bin:/bin" \
        DOCTOR_HOME="$fixture_home" \
        /bin/bash "$doctor" --toolchain-file "$manifest" --paths-only
}

make_output_mock "$primary_bin" alpha 'alpha 1.2.3'
make_output_mock "$primary_bin" gamma 'gamma 4.5.6'

success_output="$(run_doctor "$primary_bin")"
assert_contains 'OK|tool:alpha|provider=fixture' "$success_output"
assert_contains 'OK|version:alpha|value=alpha 1.2.3' "$success_output"
assert_contains 'WARN|tool:beta|missing optional command' "$success_output"
assert_contains 'OK|tool:gamma|provider=fixture' "$success_output"
assert_not_contains 'OK|system|' "$success_output"
assert_not_contains 'OK|codex:guidance|' "$success_output"

printf '#!/usr/bin/env bash\nexit 7\n' > "$primary_bin/alpha"
chmod +x "$primary_bin/alpha"
version_failure_output="$(run_doctor "$primary_bin")"
assert_contains 'WARN|version:alpha|command failed exit=7' "$version_failure_output"
make_output_mock "$primary_bin" alpha 'alpha 1.2.3'

rm "$primary_bin/alpha"
set +e
missing_output="$(run_doctor "$primary_bin" 2>&1)"
missing_status=$?
set -e
[[ "$missing_status" -eq 1 ]] || fail_test "required missing status=$missing_status"
assert_contains 'FAIL|tool:alpha|missing required command' "$missing_output"
assert_contains 'OK|tool:gamma|provider=fixture' "$missing_output"

make_mock "$secondary_bin" alpha
set +e
provider_output="$(run_doctor "$secondary_bin:$primary_bin" 2>&1)"
provider_status=$?
set -e
[[ "$provider_status" -eq 1 ]] || fail_test "provider mismatch status=$provider_status"
assert_contains 'FAIL|tool:alpha|provider mismatch' "$provider_output"
assert_contains 'OK|tool:gamma|provider=fixture' "$provider_output"

make_output_mock "$primary_bin" alpha 'alpha 1.2.3'
duplicate_output="$(run_doctor "$primary_bin:$secondary_bin")"
assert_contains 'OK|tool:alpha|provider=fixture' "$duplicate_output"
assert_contains "WARN|tool:alpha|multiple PATH entries count=2 paths=$primary_bin/alpha,$secondary_bin/alpha" "$duplicate_output"

invalid_manifest="$fixture_root/toolchain-invalid.tsv"
printf 'broken-fields\tfixture\trequired\t%s/\n' "$primary_bin" > "$invalid_manifest"
printf 'bad-requirement\tfixture\trequiredd\t%s/\t--version\n' "$primary_bin" >> "$invalid_manifest"
printf 'empty-prefix\tfixture\trequired\t\t--version\n' >> "$invalid_manifest"
printf 'bad-version\tfixture\trequired\t%s/\t--bad\n' "$primary_bin" >> "$invalid_manifest"
set +e
invalid_output="$(run_doctor_with_manifest "$primary_bin" "$invalid_manifest" 2>&1)"
invalid_status=$?
set -e
[[ "$invalid_status" -eq 1 ]] || fail_test "invalid manifest status=$invalid_status"
assert_contains 'FAIL|toolchain:line:1|expected 5 tab-separated fields actual=4' "$invalid_output"
assert_contains 'FAIL|tool:bad-requirement|invalid requirement=requiredd' "$invalid_output"
assert_contains 'FAIL|tool:empty-prefix|expected path prefix is empty' "$invalid_output"
assert_contains 'FAIL|tool:bad-version|invalid version argument=--bad' "$invalid_output"
assert_contains 'SUMMARY|failures=4|' "$invalid_output"

unreadable_manifest="$fixture_root/toolchain-unreadable.tsv"
cp "$fixture_manifest" "$unreadable_manifest"
chmod 000 "$unreadable_manifest"
set +e
unreadable_output="$(run_doctor_with_manifest "$primary_bin" "$unreadable_manifest" 2>&1)"
unreadable_status=$?
set -e
chmod 600 "$unreadable_manifest"
[[ "$unreadable_status" -eq 1 ]] || fail_test "unreadable manifest status=$unreadable_status"
assert_contains 'FAIL|toolchain|manifest unreadable:' "$unreadable_output"
assert_contains 'SUMMARY|failures=1|' "$unreadable_output"

codex_home="$fixture_home/.codex"
dotfiles_repo="$fixture_home/repos/dotfiles"
mac_setting_trust_repo="$fixture_home/repos/mac_setting"
mac_setting_repo="$mac_setting_trust_repo/.worktrees/test"
mkdir -p \
    "$codex_home/skills/running-remote-operations" \
    "$codex_home/skills/reviewing-codex-workflows" \
    "$codex_home/automations/example" \
    "$dotfiles_repo" \
    "$mac_setting_repo"
printf 'guidance\n' > "$codex_home/AGENTS.md"
printf 'automation\n' > "$codex_home/automations/example/automation.toml"
printf '[projects."%s"]\ntrust_level = "trusted"\n' \
    "$mac_setting_trust_repo" > "$codex_home/config.toml"
make_output_mock "$primary_bin" sw_vers 'TestOS 1.0'
make_output_mock "$primary_bin" uname 'arm64'
make_mock "$primary_bin" chezmoi
printf '#!/usr/bin/env bash\n[[ "${GIT_OPTIONAL_LOCKS:-}" == "0" ]] || exit 42\ncase "$*" in\n  *"rev-parse --path-format=absolute --git-common-dir"*) printf "%%s\\n" %q ;;\nesac\n' \
    "$mac_setting_trust_repo/.git" > "$primary_bin/git"
chmod +x "$primary_bin/git"

host_output="$(
    PATH="$primary_bin:/usr/bin:/bin" \
        DOCTOR_PATH="$primary_bin:/usr/bin:/bin" \
        DOCTOR_HOME="$fixture_home" \
        DOCTOR_LOGIN_SHELL='/opt/homebrew/bin/fish' \
        DOCTOR_CODEX_HOME="$codex_home" \
        DOCTOR_DOTFILES_REPO="$dotfiles_repo" \
        DOCTOR_MAC_SETTING_REPO="$mac_setting_repo" \
        /bin/bash "$doctor" --toolchain-file "$fixture_manifest"
)"
assert_contains 'OK|system|os=TestOS 1.0 arch=arm64 shell=/opt/homebrew/bin/fish' "$host_output"
assert_contains 'OK|chezmoi|status clean' "$host_output"
assert_contains 'OK|git:dotfiles|clean' "$host_output"
assert_contains 'OK|git:mac_setting|clean' "$host_output"
assert_contains 'OK|codex:guidance|present' "$host_output"
assert_contains 'OK|codex:skill:running-remote-operations|present' "$host_output"
assert_contains 'OK|codex:skill:reviewing-codex-workflows|present' "$host_output"
assert_contains 'OK|codex:automations|count=1' "$host_output"
assert_contains "OK|codex:project-trust|trusted path=$mac_setting_trust_repo" "$host_output"

printf '#!/usr/bin/env bash\nexit 23\n' > "$primary_bin/find"
chmod +x "$primary_bin/find"
set +e
find_failure_output="$(
    PATH="$primary_bin:/usr/bin:/bin" \
        DOCTOR_PATH="$primary_bin:/usr/bin:/bin" \
        DOCTOR_HOME="$fixture_home" \
        DOCTOR_CODEX_HOME="$codex_home" \
        DOCTOR_DOTFILES_REPO="$dotfiles_repo" \
        DOCTOR_MAC_SETTING_REPO="$mac_setting_repo" \
        /bin/bash "$doctor" --toolchain-file "$fixture_manifest" 2>&1
)"
find_failure_status=$?
set -e
rm "$primary_bin/find"
[[ "$find_failure_status" -eq 0 ]] || fail_test "automation scan failure status=$find_failure_status"
assert_contains 'WARN|codex:automations|scan failed exit=23' "$find_failure_output"
assert_contains "OK|codex:project-trust|trusted path=$mac_setting_trust_repo" "$find_failure_output"
assert_contains 'SUMMARY|failures=0|' "$find_failure_output"

login_shell_marker="$fixture_root/login-shell-invoked"
printf '#!/usr/bin/env bash\nprintf touched > %q\nprintf "%%s\\n" %q\n' \
    "$login_shell_marker" \
    "$secondary_bin:$primary_bin:/usr/bin:/bin" > "$secondary_bin/fish"
chmod +x "$secondary_bin/fish"
set +e
login_path_output="$(
    PATH="$primary_bin:$secondary_bin:/usr/bin:/bin" \
        DOCTOR_HOME="$fixture_home" \
        DOCTOR_LOGIN_SHELL="$secondary_bin/fish" \
        DOCTOR_CODEX_HOME="$codex_home" \
        DOCTOR_DOTFILES_REPO="$dotfiles_repo" \
        DOCTOR_MAC_SETTING_REPO="$mac_setting_repo" \
        /bin/bash "$doctor" --toolchain-file "$fixture_manifest" 2>&1
)"
login_path_status=$?
set -e
[[ "$login_path_status" -eq 0 ]] || fail_test "process PATH status=$login_path_status"
assert_contains 'OK|tool:alpha|provider=fixture' "$login_path_output"
[[ ! -e "$login_shell_marker" ]] || fail_test 'doctor must not execute login shell startup code'

printf 'doctor tests passed\n'
