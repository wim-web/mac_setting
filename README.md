# Mac設定用リポジトリ

## Setup

```
./script/setup/base.sh
./script/setup/tool.sh
```

セットアップ後、ツールの管理元とバージョン、PATH競合、chezmoi、Git、Codex配置を
読み取り専用で確認する。

```sh
bash script/doctor.sh
```

doctorは全項目を最後まで検査し、`OK`、`WARN`、`FAIL` を行単位で出力する。
必須コマンドの欠落または期待した管理元との不一致がある場合は非ゼロで終了する。
ログインシェルのstartup configは実行せず、呼び出し元の`PATH`を検査する。
別の既知PATHを検査するときだけ、`DOCTOR_PATH`で明示的に渡す。
Codexからこのリポジトリを操作するときは、`.codex/config.toml`が同じ期待PATHを
subprocessへ設定する。aqua proxyに必要なglobal configの場所だけを併せて渡し、
defaultのsecret名除外を維持する。
このproject configを有効にするには、Codexでmain checkout自体をtrustedにする。
doctorの`codex:project-trust`はworktreeでもGit common rootを使ってこの前提を確認する。

## Development checks

doctorのfixtureテスト、Homebrew一覧、bootstrap規則、シェル構文をまとめて確認する。

```sh
bash script/check.sh
```

主要コマンドの期待管理元と安全なバージョン引数は `config/toolchain.tsv`、明示的に導入するHomebrew
パッケージは `config/brew-formulae.txt` と `config/brew-casks.txt` を正本とする。

## dotfiles

https://github.com/wim-web/dotfiles by chezmoi
