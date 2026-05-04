---
name: renovate-automerge
description: このリポジトリの Renovate PR を調査し、repo固有ルールに従ってマージする時に使う。
---

# Renovate Automerge

この skill は、`wim-web/mac_setting` で Renovate が作成した open PR を確認し、以下のルールに従ってマージまたは報告する。

## 対象PR

- 作成者が Renovate の open PR のみを対象にする。
- このリポジトリで観測した Renovate author: `app/renovate`
- base branch が `main` の PR のみを対象にする。
- Dependabot や人間が作成した PR は対象外。

## 必ず確認すること

明らかなブロック条件があっても、そこで早期終了しない。影響範囲調査を完了してから、マージしてよい / マージしてはいけない / 人間確認が必要、のいずれかを判断する。

- PR title/body
- changed files
- update type
- Renovate が PR 本文に載せた release notes / changelog / compatibility notes
- upstream changelog / release notes / migration guide
- 破壊的変更、deprecated API、設定変更、peer dependency 変更、runtime 要件変更の有無
- 影響範囲: local macOS setup script / Homebrew / aqua / Docker Compose / shell script / iTerm2 設定
- check status
- merge conflict の有無
- requested changes / 未解決の人間 review comment の有無

## 調査手順

対象 PR ごとに、必ずこの順序で調査してから判定する。

1. `gh pr view PR番号 --json title,body,author,baseRefName,headRefName,isDraft,mergeable,reviewDecision,files,statusCheckRollup,commits,reviews,comments,url` で PR metadata を確認する。
2. `gh pr diff PR番号 --patch` で差分を確認する。
3. Renovate PR 本文の release notes / changelog / compatibility notes を読む。
4. upstream 公式 release notes / changelog / upgrade guide / migration guide を読む。PR 本文だけで済ませない。
5. repo 内で変更対象の参照箇所を検索し、この repo での影響範囲を確認する。
6. ここまで完了してから判定する。

## マージしてよいもの

以下をすべて満たす Renovate PR は自動マージしてよい。

- author が `app/renovate`。
- base branch が `main`。
- draft ではない。
- mergeable が `MERGEABLE`。
- failed / pending / missing check がない。この repo では `statusCheckRollup` が空の場合は required check がないものとして扱ってよい。
- requested changes がなく、未解決の人間 review comment や人間からのブロックコメントがない。
- changed files が次のいずれかだけ。
  - `script/setup/base.sh`
  - `script/setup/tool.sh`
  - `script/installer/docker-compose.sh`
  - `script/update/aqua.sh`
  - `script/update/brew.sh`
  - `script/update/docker-compose.sh`
  - `renovate.json`
- 変更内容が Renovate 管理コメントに紐づく version literal の更新だけ。
- update type が patch または minor。
- 対象 dependency が、この repo の shell script または `renovate.json` にある Renovate 管理コメントから特定できる local setup tool の更新である。
- upstream release notes / changelog / migration guide を確認し、breaking change、設定変更、runtime 要件変更、インストール方法変更、macOS arm64 配布物の廃止がないと判断できる。

## マージしてはいけないもの

以下に該当する PR は自動マージしない。必要に応じて人間確認として報告する。

- author が `app/renovate` 以外。
- base branch が `main` 以外。
- major update。
- CLI tool、package manager、installer、Docker CLI plugin の minor update で、upstream release notes / migration guide から CLI 挙動や互換性の影響を判断できないもの。
- changed files に shell script 以外の source code、iTerm2 plist、migration、DB、infra、deploy 設定が含まれるもの。
- `renovate.json` の `customManagers`、`packageRules`、schedule、automerge 設定を変更するもの。ただし既存 `extends` の version pin 更新だけで、公式 changelog を確認できる場合はマージしてよい。
- Renovate 管理コメントや version literal 以外の script logic を変更するもの。
- upstream changelog / release notes / migration guide を確認できず、影響範囲を判断できないもの。
- breaking changes、deprecated API、設定変更、peer dependency 変更、runtime 要件変更、インストール方法変更の可能性が残るもの。
- macOS arm64 の配布物、Homebrew formula/cask、または aqua installer の提供方法に互換性リスクがあるもの。
- failed / pending / missing check があるもの。ただしこの repo で `statusCheckRollup` が空の場合は missing check とは扱わない。
- merge conflict があるもの。
- requested changes や未解決の人間 review comment があるもの。

## check の扱い

- `statusCheckRollup` に failed または pending の check が 1 つでもある場合はマージしない。
- `statusCheckRollup` が空の場合、この repo では required check がないものとして扱ってよい。
- CI が追加された場合は、成功している check だけを根拠にし、required check を推測で補完しない。

## マージ方法

- `gh pr merge PR番号 --squash --delete-branch=false` を使う。
- マージ前に `gh pr view` で `mergeable` が `MERGEABLE` であることを再確認する。
- GitHub が branch deletion を無効にしているため、Renovate branch の削除は要求しない。

## post-merge action

Renovate PR をマージした場合、マージした PR ごとにローカルを更新する。複数 PR をマージする場合も、各 PR のマージ直後にその PR に対応する local update を実行し、成功してから次の PR に進む。

実行場所は、このリポジトリの root。

1. `script/setup/base.sh` または `script/setup/tool.sh` の Homebrew formula としてインストールしている package を更新した PR の場合、その PR で更新した package だけを `brew upgrade package` で更新する。package 名は Renovate の `depName` から推測せず、同じ Renovate 管理コメントに対応する `brew install` 対象または brew package 配列の文字列から読む。
2. `script/setup/tool.sh` の Homebrew cask 配列にある cask を更新した PR の場合、その PR で更新した cask だけを `brew upgrade --cask cask` で更新する。cask 名は Renovate の `depName` から推測せず、同じ Renovate 管理コメント直後の cask 文字列から読む。
3. `script/installer/docker-compose.sh` または `script/update/docker-compose.sh` に関係する PR の場合、`./script/update/docker-compose.sh` を実行する。
4. `script/setup/tool.sh`、`script/update/aqua.sh`、または `renovate.json` の aqua installer / aqua Renovate config に関係する PR の場合、`./script/update/aqua.sh` を実行する。

成功確認は各 command の exit code 0。失敗した場合は以降の post-merge action を止め、失敗した command、exit code、stdout/stderr の要点を報告する。

`./script/update/brew.sh` は post-merge action として実行しない。Homebrew 本体の version literal だけを更新した PR は、この repo に対応する local update command がないため、マージ後に「local update command なし」と報告する。

## 報告

最後に以下を日本語で報告する。

- マージした PR 番号、title、対象 dependency、update type。
- マージ後に実行した post-merge action と結果。
- マージしなかった PR 番号、title、理由、人間確認が必要な点。
- 対象となる Renovate PR がない場合は「対象なし」と報告する。

## PR コメント

マージしなかった Renovate PR に自動でコメントを残すのは、次の条件をすべて満たす場合だけ。

- PR がこの skill の対象である。
- 調査済みで、自動マージしない理由が明確。
- コメントが人間確認の助けになる。

コメントには以下を含める。

- 自動マージしなかった理由。
- 変更ファイルと影響範囲。
- 確認した release notes / changelog / migration guide。
- 人間が確認すべき具体的な論点。

コメント例:

```md
Renovate automerge 調査結果:

- 自動マージしませんでした: major update のため。
- 変更ファイル: `script/setup/tool.sh`
- 影響範囲: macOS local setup の Homebrew formula version
- 確認ポイント: upstream release notes / migration guide で CLI 互換性、macOS arm64 配布、Homebrew formula の変更有無を確認してください。
```

## 禁止操作

- Renovate branch に commit や push をしない。
- PR を close しない。
- この skill に明記されていない条件の PR はマージしない。
- release / deploy を推測で実行しない。
- Renovate の `depName` だけを根拠に package 名を推測して `brew upgrade`、`brew upgrade --cask`、`brew reinstall` などを実行しない。
