# Environment Doctor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mac上のツール管理元、PATH競合、chezmoi/Git/Codex配置を読み取り専用で検査し、セットアップの期待状態を継続検証できるようにする。

**Architecture:** `config/toolchain.tsv` を主要コマンドの期待管理元として、`script/doctor.sh` が全検査を継続して `OK|WARN|FAIL` 形式で集約する。fixture PATHを使うシェルテストを先に作り、セットアップのパッケージ一覧もファイルへ分離して同じ正本を利用する。

**Tech Stack:** Bash 3.2互換、zsh、Homebrew、chezmoi、GitHub Actions

---

### Task 1: doctorの失敗する振る舞いテストを書く

**Files:**
- Create: `test/doctor_test.sh`
- Create: `test/fixtures/toolchain-ok.tsv`

- [x] **Step 1: fixtureとテストを書く**

```text
alpha	fixture	required	/fixture/bin/alpha
beta	fixture	optional	/fixture/bin/beta
```

`test/doctor_test.sh` は一時ディレクトリにmock executableを作り、次を個別ケースで検証する。

```bash
run_doctor() {
  PATH="$fixture_bin:/usr/bin:/bin" \
  DOCTOR_HOME="$fixture_home" \
  "$repo_root/script/doctor.sh" --toolchain-file "$fixture_manifest" --paths-only
}

assert_contains 'OK|tool:alpha|provider=fixture' "$output"
assert_contains 'WARN|tool:beta|missing optional command' "$output"
assert_exit 1 "$missing_required_status"
assert_contains 'FAIL|tool:alpha|missing required command' "$missing_required_output"
assert_contains 'OK|tool:gamma|' "$missing_required_output"
```

- [x] **Step 2: REDを確認する**

Run: `bash test/doctor_test.sh`

Expected: `script/doctor.sh` が存在せず非ゼロ終了。

### Task 2: toolchain manifestとdoctorを最小実装する

**Files:**
- Create: `config/toolchain.tsv`
- Create: `script/doctor.sh`
- Modify: `test/doctor_test.sh`

- [x] **Step 1: 実機の期待管理元をmanifestへ記録する**

```text
# command	provider	requirement	expected-path-prefix
fish	homebrew	required	/opt/homebrew/
brew	homebrew	required	/opt/homebrew/
codex	homebrew	required	/opt/homebrew/
git	homebrew	required	/opt/homebrew/
gh	aqua	required	${HOME}/.local/share/aquaproj-aqua/bin/
go	aqua	required	${HOME}/.local/share/aquaproj-aqua/bin/
jq	aqua	required	${HOME}/.local/share/aquaproj-aqua/bin/
mise	homebrew	required	/opt/homebrew/
node	homebrew	required	/opt/homebrew/
bun	homebrew	required	/opt/homebrew/
pnpm	homebrew	required	/opt/homebrew/
python3	homebrew	required	/opt/homebrew/
uv	standalone	required	${HOME}/.local/bin/
rustc	rustup	required	${HOME}/.cargo/bin/
cargo	rustup	required	${HOME}/.cargo/bin/
docker	docker-desktop	required	/usr/local/bin/
```

- [x] **Step 2: 全件継続するdoctorを実装する**

`script/doctor.sh` は `--toolchain-file` と `--paths-only` を受け取り、manifestをタブ区切りで読み込む。`${HOME}` だけを `DOCTOR_HOME` へ安全に展開し、`command -v` の実体が期待prefix外ならFAIL、optional欠落と重複PATHはWARN、required欠落はFAILとする。検査途中で終了せず、FAIL件数が1以上なら最後にexit 1する。

- [x] **Step 3: GREENを確認する**

Run: `bash test/doctor_test.sh`

Expected: 全ケースPASS。

- [x] **Step 4: ホスト検査を追加するテストを先に書く**

テストで `--paths-only` 時にhost検査が出ないこと、通常時に `system`、`chezmoi`、`git:dotfiles`、`git:mac_setting`、`codex:guidance`、2つのskill、Automationの各行が出ることを検証する。

- [x] **Step 5: ホスト検査を実装して全テストを通す**

Run: `bash test/doctor_test.sh`

Expected: 全ケースPASS。

- [x] **Step 6: コミットする**

```bash
git add config/toolchain.tsv script/doctor.sh test/doctor_test.sh test/fixtures/toolchain-ok.tsv
git commit -m "feat: add read-only environment doctor"
```

### Task 3: Homebrew管理一覧を正本化する

**Files:**
- Create: `config/brew-formulae.txt`
- Create: `config/brew-casks.txt`
- Create: `test/setup_lists_test.sh`
- Modify: `script/setup/tool.sh`

- [x] **Step 1: 現在の全パッケージを期待する失敗テストを書く**

`test/setup_lists_test.sh` は重複・空白・未ソートを拒否し、既存4 formulaと既存21 caskが一度ずつ存在することを検証する。

- [x] **Step 2: REDを確認する**

Run: `bash test/setup_lists_test.sh`

Expected: 2つの一覧ファイルが存在せずFAIL。

- [x] **Step 3: 一覧ファイルを追加してtool.shから読む**

```bash
install_brew_list() {
  local kind="$1"
  local list_file="$2"
  local package
  while IFS= read -r package; do
    [[ -z "$package" || "$package" == \#* ]] && continue
    if brew list --"$kind" "$package" >/dev/null 2>&1; then
      printf '%s already installed\n' "$package"
    else
      brew install ${kind/cask/--cask} "$package"
    fi
  done < "$list_file"
}
```

実装時はformulaとcaskで引数を明示分岐し、文字列置換で空引数を生成しない。

- [x] **Step 4: GREENと構文を確認する**

Run: `bash test/setup_lists_test.sh && bash -n script/setup/tool.sh`

Expected: 成功。

- [x] **Step 5: コミットする**

```bash
git add config/brew-formulae.txt config/brew-casks.txt test/setup_lists_test.sh script/setup/tool.sh
git commit -m "refactor: centralize homebrew package lists"
```

### Task 4: baseセットアップの安全性を改善する

**Files:**
- Create: `test/base_setup_test.sh`
- Modify: `script/setup/base.sh`

- [x] **Step 1: 静的な失敗テストを書く**

```bash
grep -Fq 'set -euo pipefail' script/setup/base.sh
grep -Fq 'mktemp -d' script/setup/base.sh
grep -Fq "trap 'rm -rf" script/setup/base.sh
! grep -Fq '/tmp/hackgen.zip' script/setup/base.sh
! grep -Eq 'echo \$\(which fish\)' script/setup/base.sh
```

- [x] **Step 2: REDを確認する**

Run: `bash test/base_setup_test.sh`

Expected: strict modeと安全な一時ディレクトリがなくFAIL。

- [x] **Step 3: 最小修正する**

`base.sh` にzsh strict modeを追加し、`command -v` と引用を使う。フォント取得は `mktemp -d` で作ったディレクトリへ保存し、trapで削除する。

- [x] **Step 4: GREENと構文を確認する**

Run: `bash test/base_setup_test.sh && zsh -n script/setup/base.sh`

Expected: 成功。

- [x] **Step 5: コミットする**

```bash
git add test/base_setup_test.sh script/setup/base.sh
git commit -m "fix: harden mac bootstrap script"
```

### Task 5: ローカル検証入口とGitHub Actionsを追加する

**Files:**
- Create: `script/check.sh`
- Create: `.github/workflows/check.yml`
- Modify: `README.md`

- [x] **Step 1: check.shを追加する**

```bash
#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
bash test/doctor_test.sh
bash test/setup_lists_test.sh
bash test/base_setup_test.sh
bash -n script/setup/tool.sh script/doctor.sh script/check.sh
zsh -n script/setup/base.sh
```

- [x] **Step 2: ローカルで成功を確認する**

Run: `bash script/check.sh`

Expected: 全テストと構文検査が成功。

- [x] **Step 3: SHA固定workflowを追加する**

```yaml
name: check
on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:
permissions:
  contents: read
concurrency:
  group: check-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
jobs:
  check:
    runs-on: macos-15
    timeout-minutes: 10
    steps:
      - name: Checkout
        uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7.0.0
      - name: Run checks
        run: bash script/check.sh
```

このSHAが `actions/checkout` v7.0.0 を指すことは `gh release view` と既存workflowで確認済み。更新時もタグではなく実SHAを使う。

- [x] **Step 4: workflowとREADMEを検証する**

Run: `rg 'uses: .+@[0-9a-f]{40}' .github/workflows/check.yml && bash script/check.sh`

Expected: SHA固定行が一致し、全検査成功。

- [x] **Step 5: 実機doctorを実行する**

Run: `bash script/doctor.sh`

Expected: 全検査を最後まで出力。既知の競合はWARN、期待管理元の不一致がなければFAILなし。

- [x] **Step 6: READMEを更新しコミットする**

READMEへセットアップ後の `bash script/doctor.sh` と開発時の `bash script/check.sh` を追加する。

```bash
git add script/check.sh .github/workflows/check.yml README.md
git commit -m "ci: verify mac environment scripts"
```

### Task 6: 横断検証する

**Files:**
- Verify only

- [x] **Step 1: 全ローカル検証を再実行する**

Run: `bash script/check.sh && bash script/doctor.sh`

Expected: checkは成功し、doctorは全項目を集約する。

- [x] **Step 2: 差分品質を確認する**

```bash
git diff --check HEAD~5..HEAD
git status --short
```

Expected: whitespace errorなし、作業ツリーclean。
