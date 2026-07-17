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

make_mock "$primary_bin" alpha
make_mock "$primary_bin" gamma

success_output="$(run_doctor "$primary_bin")"
assert_contains 'OK|tool:alpha|provider=fixture' "$success_output"
assert_contains 'WARN|tool:beta|missing optional command' "$success_output"
assert_contains 'OK|tool:gamma|provider=fixture' "$success_output"

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

make_mock "$primary_bin" alpha
duplicate_output="$(run_doctor "$primary_bin:$secondary_bin")"
assert_contains 'OK|tool:alpha|provider=fixture' "$duplicate_output"
assert_contains 'WARN|tool:alpha|multiple PATH entries' "$duplicate_output"

invalid_manifest="$fixture_root/toolchain-invalid.tsv"
printf 'broken-fields\tfixture\trequired\n' > "$invalid_manifest"
printf 'bad-requirement\tfixture\trequiredd\t%s/\n' "$primary_bin" >> "$invalid_manifest"
printf 'empty-prefix\tfixture\trequired\t\n' >> "$invalid_manifest"
set +e
invalid_output="$(run_doctor_with_manifest "$primary_bin" "$invalid_manifest" 2>&1)"
invalid_status=$?
set -e
[[ "$invalid_status" -eq 1 ]] || fail_test "invalid manifest status=$invalid_status"
assert_contains 'FAIL|toolchain:line:1|expected 4 tab-separated fields actual=3' "$invalid_output"
assert_contains 'FAIL|tool:bad-requirement|invalid requirement=requiredd' "$invalid_output"
assert_contains 'FAIL|tool:empty-prefix|expected path prefix is empty' "$invalid_output"
assert_contains 'SUMMARY|failures=3|' "$invalid_output"

codex_home="$fixture_home/.codex"
dotfiles_repo="$fixture_home/repos/dotfiles"
mac_setting_repo="$fixture_home/repos/mac_setting"
mkdir -p \
    "$codex_home/skills/running-remote-operations" \
    "$codex_home/skills/reviewing-codex-workflows" \
    "$codex_home/automations/example" \
    "$dotfiles_repo" \
    "$mac_setting_repo"
printf 'guidance\n' > "$codex_home/AGENTS.md"
printf 'automation\n' > "$codex_home/automations/example/automation.toml"
make_output_mock "$primary_bin" sw_vers 'TestOS 1.0'
make_output_mock "$primary_bin" uname 'arm64'
make_mock "$primary_bin" chezmoi
make_mock "$primary_bin" git

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

make_output_mock "$secondary_bin" fish "$primary_bin:$secondary_bin:/usr/bin:/bin"
set +e
login_path_output="$(
    PATH="$secondary_bin:$primary_bin:/usr/bin:/bin" \
        DOCTOR_HOME="$fixture_home" \
        DOCTOR_LOGIN_SHELL="$secondary_bin/fish" \
        DOCTOR_CODEX_HOME="$codex_home" \
        DOCTOR_DOTFILES_REPO="$dotfiles_repo" \
        DOCTOR_MAC_SETTING_REPO="$mac_setting_repo" \
        /bin/bash "$doctor" --toolchain-file "$fixture_manifest" 2>&1
)"
login_path_status=$?
set -e
[[ "$login_path_status" -eq 0 ]] || fail_test "login PATH status=$login_path_status"
assert_contains 'OK|tool:alpha|provider=fixture' "$login_path_output"

printf 'doctor tests passed\n'
