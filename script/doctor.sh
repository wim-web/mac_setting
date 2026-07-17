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
    if [[ -n "${DOCTOR_PATH:-}" ]]; then
        inspection_path="$DOCTOR_PATH"
        inspection_path_source='override'
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
    local manifest_line parsed_line line_number column_count
    local command_name provider requirement expected_prefix version_argument
    local resolved_path path_entries path_entry path_count path_list
    local version_output version_status version_value

    if [[ ! -f "$toolchain_file" ]]; then
        emit_fail 'toolchain' "manifest missing: $toolchain_file"
        return
    fi
    if [[ ! -r "$toolchain_file" ]]; then
        emit_fail 'toolchain' "manifest unreadable: $toolchain_file"
        return
    fi
    if ! exec 3< "$toolchain_file"; then
        emit_fail 'toolchain' "manifest open failed: $toolchain_file"
        return
    fi

    line_number=0
    while IFS= read -r manifest_line || [[ -n "$manifest_line" ]]; do
        line_number=$((line_number + 1))
        [[ -z "$manifest_line" || "$manifest_line" == \#* ]] && continue

        column_count="$(printf '%s\n' "$manifest_line" | awk -F '\t' '{ print NF }')"
        if [[ "$column_count" -ne 5 ]]; then
            emit_fail "toolchain:line:$line_number" \
                "expected 5 tab-separated fields actual=$column_count"
            continue
        fi

        parsed_line="${manifest_line//$'\t'/$'\034'}"
        IFS=$'\034' read -r \
            command_name provider requirement expected_prefix version_argument \
            <<< "$parsed_line"
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
        if [[ "$version_argument" != '--version' && "$version_argument" != 'version' ]]; then
            emit_fail "tool:$command_name" \
                "invalid version argument=$version_argument"
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

        set +e
        version_output="$(LC_ALL=C "$resolved_path" "$version_argument" 2>&1)"
        version_status=$?
        set -e
        if [[ "$version_status" -ne 0 ]]; then
            emit_warn "version:$command_name" "command failed exit=$version_status"
        elif [[ -z "$version_output" ]]; then
            emit_warn "version:$command_name" 'command returned empty output'
        else
            version_value="${version_output%%$'\n'*}"
            version_value="${version_value//$'\r'/}"
            version_value="${version_value//|/:}"
            version_value="${version_value:0:160}"
            emit_ok "version:$command_name" "value=$version_value"
        fi

        path_entries="$(type -a -p "$command_name" 2>/dev/null | awk '!seen[$0]++')"
        path_count=0
        path_list=''
        while IFS= read -r path_entry; do
            [[ -z "$path_entry" ]] && continue
            path_count=$((path_count + 1))
            if [[ -z "$path_list" ]]; then
                path_list="$path_entry"
            else
                path_list="$path_list,$path_entry"
            fi
        done <<< "$path_entries"
        if [[ "$path_count" -gt 1 ]]; then
            emit_warn "tool:$command_name" \
                "multiple PATH entries count=$path_count paths=$path_list"
        fi
    done <&3
    exec 3<&-
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
    status_output="$(GIT_OPTIONAL_LOCKS=0 git -C "$repo_path" status --porcelain 2>&1)"
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

check_codex_project_trust() {
    local config_path="$1"
    local project_path="$2"
    local expected_section current_section line trust_found

    if [[ ! -r "$config_path" ]]; then
        emit_fail 'codex:project-trust' "config unreadable path=$config_path"
        return
    fi

    expected_section="[projects.\"$project_path\"]"
    current_section=''
    trust_found=false
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == \[*\] ]]; then
            current_section="$line"
            continue
        fi
        if [[ "$current_section" == "$expected_section" && "$line" == 'trust_level = "trusted"' ]]; then
            trust_found=true
            break
        fi
    done < "$config_path"

    if [[ "$trust_found" == true ]]; then
        emit_ok 'codex:project-trust' "trusted path=$project_path"
    else
        emit_fail 'codex:project-trust' "trusted entry missing path=$project_path"
    fi
}

resolve_codex_trust_repo() {
    local repo_path="$1"
    local common_dir git_status

    set +e
    common_dir="$(
        GIT_OPTIONAL_LOCKS=0 git -C "$repo_path" \
            rev-parse --path-format=absolute --git-common-dir 2>/dev/null
    )"
    git_status=$?
    set -e

    common_dir="${common_dir%/}"
    if [[ "$git_status" -eq 0 && "${common_dir##*/}" == '.git' ]]; then
        printf '%s\n' "${common_dir%/.git}"
    else
        printf '%s\n' "${repo_path%/}"
    fi
}

check_codex() {
    local mac_setting_repo="$1"
    local codex_home codex_config automation_count automation_files find_status automation_file
    codex_home="${DOCTOR_CODEX_HOME:-${CODEX_HOME:-$doctor_home/.codex}}"
    codex_config="${DOCTOR_CODEX_CONFIG:-$codex_home/config.toml}"

    check_codex_file 'codex:guidance' "$codex_home/AGENTS.md"
    check_codex_directory \
        'codex:skill:running-remote-operations' \
        "$codex_home/skills/running-remote-operations"
    check_codex_directory \
        'codex:skill:reviewing-codex-workflows' \
        "$codex_home/skills/reviewing-codex-workflows"

    automation_count=0
    if [[ -d "$codex_home/automations" ]]; then
        set +e
        automation_files="$(
            find "$codex_home/automations" \
                -mindepth 2 -maxdepth 2 -name automation.toml -type f -print 2>/dev/null
        )"
        find_status=$?
        set -e
        if [[ "$find_status" -ne 0 ]]; then
            emit_warn 'codex:automations' "scan failed exit=$find_status"
            return
        fi
        while IFS= read -r automation_file; do
            [[ -n "$automation_file" ]] && automation_count=$((automation_count + 1))
        done <<< "$automation_files"
    fi
    if [[ "$automation_count" -gt 0 ]]; then
        emit_ok 'codex:automations' "count=$automation_count"
    else
        emit_warn 'codex:automations' 'count=0'
    fi

    check_codex_project_trust "$codex_config" "$mac_setting_repo"
}

check_host() {
    local dotfiles_repo mac_setting_repo codex_trust_repo
    dotfiles_repo="${DOCTOR_DOTFILES_REPO:-$doctor_home/program/ghq/github.com/wim-web/dotfiles}"
    mac_setting_repo="${DOCTOR_MAC_SETTING_REPO:-$repo_root}"

    check_system
    check_chezmoi
    check_git_repo 'dotfiles' "$dotfiles_repo"
    check_git_repo 'mac_setting' "$mac_setting_repo"
    codex_trust_repo="$(resolve_codex_trust_repo "$mac_setting_repo")"
    check_codex "$codex_trust_repo"
}

configure_inspection_path
export PATH="$inspection_path"

check_toolchain

if [[ "$paths_only" == false ]]; then
    check_host
fi

printf 'SUMMARY|failures=%d|warnings=%d\n' "$failures" "$warnings"
[[ "$failures" -eq 0 ]]
