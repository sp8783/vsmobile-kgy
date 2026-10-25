# リリース

リリース PR（`release/vX.Y.Z` → main）をマージすると、CI → デプロイ → finalize（タグ・GitHub Release・Issue クローズ・Project の Done）が自動で進み、起動時に告知が出ます。

## 告知文

`config/release_notes/v{x.y.z}.yml` に告知文を置くと、そのバージョンのデプロイ後の起動時に、アプリ内お知らせの公開と Discord への投稿が自動で行われます（告知済みのバージョンは `release_announcements` に記録され、二重に告知しません）。

```yaml
title: "🚀 v2.6.0 アップデートのお知らせ"   # アプリ内お知らせのタイトル
body: |                                    # アプリ内お知らせの本文（Markdown。絵文字は Unicode）
  今回は…
discord: |                                 # Discord の本文（:shortcode: 可、2,000 文字以内）。省略すると Discord には投稿しない
  @everyone
  …
```

- Discord の投稿先は管理画面「Discord チャンネル設定」の「リリース告知」で設定します
- Discord への投稿に失敗した場合は、告知の作成から 3 日以内であれば次回の起動時に再送します

## リリース後の作業（finalize）

リリース PR のデプロイが成功すると、Deploy ワークフローの `finalize` が次を行います（hotfix など、リリース PR 以外のデプロイでは何もしません）。

- annotated tag `vX.Y.Z` と GitHub Release（Latest）を作る。中身はリリース PR 本文の「## 主な変更」の箇条書き（タグのメッセージからは `(#123)` の PR 番号を外す）
- そのリリースに含まれる Issue（リリースブランチにマージした PR とリリース PR の `Closes #N`）を閉じる
- GitHub Project のステータスを Done にする（Secret `MOBILE_SUITS_UPDATE_TOKEN` に Projects の書き込みがあるとき）

何度実行しても、済んだ作業はやり直しません。失敗したときは Deploy ワークフローの `finalize` を再実行するか、次を実行します。

```bash
SHA=<マージコミット> GITHUB_REPOSITORY=sp8783/vsmobile-kgy bin/rails release:finalize
```

実装は `lib/release_finalizer.rb` です。
