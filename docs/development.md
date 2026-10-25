# 開発環境

## 必要なもの

- Ruby 4.0.9（`.ruby-version`）
- Docker（PostgreSQL 用）
- Node.js（Tailwind CSS のビルド用）

## 起動

```bash
git clone https://github.com/sp8783/vsmobile-kgy.git
cd vsmobile-kgy
bundle install
docker compose up -d        # PostgreSQL を起動（ポート 5433）
bin/setup                   # DB の準備とサンプルデータの作成をして、開発サーバーを起動
```

2 回目以降は `bin/dev` で起動します。起動時に機体マスタ（`db/data/units.json`）が自動で反映されます。

## サンプルデータ

初回の `bin/setup` で、ローカル確認用のサンプルデータが作られます。

- ログイン: `sample_a` 〜 `sample_f`（パスワード `password`）、管理者は `admin`（パスワード `password`）
- 過去のイベント 3 件（最後まで記録済みのローテーションと、詳細統計つきの試合）、開催中のイベント 1 件（入力済み・未入力・スキップ・現在・予定の試合がそろったローテーション）、これから開催するイベント 2 件（明日・1 週間後）
- お気に入り機体の数がユーザーごとに異なる（18 機・10 機・6 機・3 機・1 機・0 機）

データを最初の状態に戻すときは、次を実行します。開発用 DB のデータはすべて消えます（`bin/db-pull` で取り込んだデータも消えます）。

```bash
bin/rails dev:sample_data
```

機体は、その時点の機体マスタから選ばれます。機体が増えても、作り直しは必須ではありません。

## 本番のデータで確認する

`bin/db-pull` で本番 DB のデータをローカルの Docker コンテナの DB に取り込めます。本番の Webhook URL も入るので、Discord に投稿する操作を試す前に `DiscordChannel` の `webhook_url` を消してください。

## Discord の投稿をローカルで試す

`config/discord.local.yml.example` を `config/discord.local.yml` にコピーし、テスト用の Webhook URL とフォーラムの記事の URL を書いておくと、サンプルデータの作成時に設定されます（Git の管理対象外）。

- `webhooks.default` の Webhook がすべての投稿先に使われます。投稿先ごとに書くと、そちらが優先されます
- イベントフォーラム（`webhooks.event_forum`）には、フォーラムのチャンネルで作った Webhook が必要です
- `event_thread_url` は、これから開催するサンプルのイベント（明日・1 週間後）の「Discord フォーラムスレッド URL」に入ります。サンプルデータを作ったあと `bin/rails runner 'EventReminderJob.perform_now(now: Time.current.change(hour: 8))'` を実行すると、前日・1 週間前のリマインドと事前準備のお願いを試せます（投稿文の初期設定の時刻 8 時として実行します。一度送った投稿は、サンプルデータを作り直すまで再び送りません）
- 本番の Webhook は書かないでください
