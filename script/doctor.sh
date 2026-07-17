#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
toolchain_file="$repo_root/config/toolchain.tsv"
paths_only=false
doctor_home="${DOCTOR_HOME:-$HOME}"
inspection_path="$PATH"
inspection_path_source='process'
failures=0
warnings=0

usage() {
    printf 'Usage: %s [--toolchain-file PATH] [--paths-only]\n' "$0"
}

emit_ok() {
    printf 'OK|%s|%s\n' "$1" "$2"
}

emit_warn() {
    warnings=$((warnings + 1))
    printf 'WARN|%s|%s\n' "$1" "$2"
}

emit_fail() {
    failures=$((failures + 1))
    printf 'FAIL|%s|%s\n' "$1" "$2"
}

configure_inspection_path() {
    local login_shell candidate_path shell_status

    if [[ -n "${DOCTOR_PATH:-}" ]]; then
        inspection_path="$DOCTOR_PATH"
        inspection_path_source='override'
        return
    fi

    login_shell="${DOCTOR_LOGIN_SHELL:-${SHELL:-}}"
    [[ -n "$login_shell" && -x "$login_shell" ]] || return

    set +e
    if [[ "$(basename "$login_shell")" == 'fish' ]]; then
        candidate_path="$("$login_shell" -lc 'string join : $PATH' 2>/dev/null)"
    else
        candidate_path="$("$login_shell" -lc 'printf "%s\\n" "$PATH"' 2>/dev/null)"
    fi
    shell_status=$?
    set -e

    if [[ "$shell_status" -eq 0 && -n "$candidate_path" ]]; then
        inspection_path="$candidate_path"
        inspection_path_source='login-shell'
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --toolchain-file)
            [[ $# -ge 2 ]] || { usage >&2; exit 2; }
            toolchain_file="$2"
            shift 2
            ;;
        --paths-only)
            paths_only=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

check_toolchain() {
    local manifest_line line_number column_count
    local command_name provider requirement expected_prefix resolved_path path_count

    if [[ ! -f "$toolchain_file" ]]; then
        emit_fail 'toolchain' "manifest missing: $toolchain_file"
        return
    fi

    line_number=0
    while IFS= read -r manifest_line || [[ -n "$manifest_line" ]]; do
        line_number=$((line_number + 1))
        [[ -z "$manifest_line" || "$manifest_line" == \#* ]] && continue

        column_count="$(printf '%s\n' "$manifest_line" | awk -F '\t' '{ print NF }')"
        if [[ "$column_count" -ne 4 ]]; then
            emit_fail "toolchain:line:$line_number" \
                "expected 4 tab-separated fields actual=$column_count"
            continue
        fi

        IFS=$'\t' read -r command_name provider requirement expected_prefix <<< "$manifest_line"
        if [[ -z "$command_name" ]]; then
            emit_fail "toolchain:line:$line_number" 'command is empty'
            continue
        fi
        if [[ -z "$provider" ]]; then
            emit_fail "tool:$command_name" 'provider is empty'
            continue
        fi
        if [[ "$requirement" != 'required' && "$requirement" != 'optional' ]]; then
            emit_fail "tool:$command_name" "invalid requirement=$requirement"
            continue
        fi
        if [[ -z "$expected_prefix" ]]; then
            emit_fail "tool:$command_name" 'expected path prefix is empty'
            continue
        fi

        expected_prefix="${expected_prefix//\$\{HOME\}/$doctor_home}"

        if ! resolved_path="$(command -v "$command_name" 2>/dev/null)"; then
            if [[ "$requirement" == 'required' ]]; then
                emit_fail "tool:$command_name" 'missing required command'
            else
                emit_warn "tool:$command_name" 'missing optional command'
            fi
            continue
        fi

        case "$resolved_path" in
            "$expected_prefix"*)
                emit_ok "tool:$command_name" "provider=$provider path=$resolved_path"
                ;;
            *)
                emit_fail "tool:$command_name" "provider mismatch expected=$provider prefix=$expected_prefix actual=$resolved_path"
                ;;
        esac

        path_count="$(type -a -p "$command_name" 2>/dev/null | awk '!seen[$0]++' | wc -l | tr -d ' ')"
        if [[ "$path_count" -gt 1 ]]; then
            emit_warn "tool:$command_name" "multiple PATH entries count=$path_count"
        fi
    done < "$toolchain_file"
}

check_system() {
    local os_version architecture login_shell
    os_version="$(sw_vers -productVersion 2>/dev/null || printf 'unknown')"
    architecture="$(uname -m 2>/dev/null || printf 'unknown')"
    login_shell="${DOCTOR_LOGIN_SHELL:-${SHELL:-unknown}}"
    emit_ok 'system' "os=$os_version arch=$architecture shell=$login_shell path_source=$inspection_path_source"
}

check_chezmoi() {
    local status_output status_code
    if ! command -v chezmoi >/dev/null 2>&1; then
        emit_warn 'chezmoi' 'command missing'
        return
    fi

    set +e
    status_output="$(chezmoi status 2>&1)"
    status_code=$?
    set -e
    if [[ "$status_code" -ne 0 ]]; then
        emit_warn 'chezmoi' "status failed exit=$status_code"
    elif [[ -n "$status_output" ]]; then
        emit_warn 'chezmoi' 'unapplied changes present'
    else
        emit_ok 'chezmoi' 'status clean'
    fi
}

check_git_repo() {
    local label="$1"
    local repo_path="$2"
    local status_output status_code

    if [[ ! -d "$repo_path" ]]; then
        emit_warn "git:$label" "repository missing path=$repo_path"
        return
    fi

    set +e
    status_output="$(git -C "$repo_path" status --porcelain 2>&1)"
    status_code=$?
    set -e
    if [[ "$status_code" -ne 0 ]]; then
        emit_warn "git:$label" "status failed exit=$status_code"
    elif [[ -n "$status_output" ]]; then
        emit_warn "git:$label" 'working tree has changes'
    else
        emit_ok "git:$label" 'clean'
    fi
}

check_codex_file() {
    local label="$1"
    local target="$2"
    if [[ -f "$target" ]]; then
        emit_ok "$label" "present path=$target"
    else
        emit_fail "$label" "missing path=$target"
    fi
}

check_codex_directory() {
    local label="$1"
    local target="$2"
    if [[ -d "$target" ]]; then
        emit_ok "$label" "present path=$target"
    else
        emit_fail "$label" "missing path=$target"
    fi
}

check_codex() {
    local codex_home automation_count
    codex_home="${DOCTOR_CODEX_HOME:-${CODEX_HOME:-$doctor_home/.codex}}"

    check_codex_file 'codex:guidance' "$codex_home/AGENTS.md"
    check_codex_directory \
        'codex:skill:running-remote-operations' \
        "$codex_home/skills/running-remote-operations"
    check_codex_directory \
        'codex:skill:reviewing-codex-workflows' \
        "$codex_home/skills/reviewing-codex-workflows"

    automation_count=0
    if [[ -d "$codex_home/automations" ]]; then
        automation_count="$(find "$codex_home/automations" -mindepth 2 -maxdepth 2 -name automation.toml -type f | wc -l | tr -d ' ')"
    fi
    if [[ "$automation_count" -gt 0 ]]; then
        emit_ok 'codex:automations' "count=$automation_count"
    else
        emit_warn 'codex:automations' 'count=0'
    fi
}

check_host() {
    local dotfiles_repo mac_setting_repo
    dotfiles_repo="${DOCTOR_DOTFILES_REPO:-$doctor_home/program/ghq/github.com/wim-web/dotfiles}"
    mac_setting_repo="${DOCTOR_MAC_SETTING_REPO:-$repo_root}"

    check_system
    check_chezmoi
    check_git_repo 'dotfiles' "$dotfiles_repo"
    check_git_repo 'mac_setting' "$mac_setting_repo"
    check_codex
}

configure_inspection_path
export PATH="$inspection_path"

check_toolchain

if [[ "$paths_only" == false ]]; then
    check_host
fi

printf 'SUMMARY|failures=%d|warnings=%d\n' "$failures" "$warnings"
[[ "$failures" -eq 0 ]]
