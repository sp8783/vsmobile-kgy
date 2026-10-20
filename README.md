# VS.Mobile for KGY

KGYコミュニティ向けの対戦会運営支援Webアプリです。「機動戦士ガンダム エクストリームバーサス2 インフィニットブースト」のローテーション表管理・試合記録・戦績統計を提供します。

## 機能

**対戦会管理**
- 対戦会の作成・編集と、4〜8人からのローテーション表自動生成（スロットはランダム割り当て。次周は休みのタイミングを前周と揃えつつ、対戦カード・配信台パターンが重複しないよう生成）
- 公平性チェック画面で参加者ごとの登録対戦数・配信台経験を確認しながら進行
- リアルタイムの試合進行共有・ワンクリック結果記録（結果を入力せずに次の試合へ進め、結果が未入力の試合はあとから入力可能）
- 結果入力の機体選択は、お気に入り機体を画像でワンタップ、プルダウンの先頭には最近使った機体（お気に入りを除く10機体）
- 配信アーカイブのタイムスタンプを解析し、試合統計データを自動取り込み

**対戦履歴**
- 機体画像・コストバッジ付きカードスタイルの一覧表示
- イベント・ユーザー・機体・コスト・同チーム組み合わせなど多様なフィルター
- お気に入り登録・新着順/古い順ソート・詳細画面からの戻りでフィルター状態を保持

**戦績・統計**
- 個人・全体の総合戦績（勝率・コスト帯別・対面相性など）
- イベント別・機体別・パートナー別の詳細統計（各行クリックで関連画面へ遷移）
- 機体別タブは並び替えで選んだ指標（使用回数・勝率・与/被ダメ・EX・OL率・生存など）の数値とバーを連動表示し、勝率を常時併記
- 各画面の機体名から機体詳細ページへワンクリックで遷移
- プレイ分析（EXバースト活用・生存時間などのコミュニティ比較）

**機体一覧**
- 全登録機体をコスト順で一覧表示
- サイト内機体詳細ページ・各機体の外部Wikiへもワンクリックで参照

**Discord連携**
- Webhook経由のイベントリマインド自動送信（初期設定は7日前・前日の8時）と、イベントのフォーラム記事への事前準備のお願いの投稿
- 対戦会のあとに各試合の統計・配信アーカイブのタイムスタンプが全試合そろうと、イベントのフォーラム記事へ「登録しました」を自動投稿（統計・タイムスタンプそれぞれ 1 回。同時にそろえば 1 回にまとめる）
- 投稿先（Webhook）と投稿文（文面・送るタイミング・送る/送らない。登録の連絡は文面と送る/送らない）は、管理画面の「Discord設定」で設定（投稿文はプレビューつき）
- 指定チャンネルへの配信URL手動投稿

**マイページ**
- お気に入り機体（最大18機）の登録。機体選択では「選択中」で絞り込んでその場で外せる
- お気に入り機体の並び替え（ドラッグで個別に移動、コスト順・使用回数順でまとめて並べ替え）

**その他**
- ゲスト閲覧モード（プレイヤー名を匿名化し、配信リンクとリアクションの実名表示を無効化）
- PWA対応・プッシュ通知（出番通知）・レスポンシブデザイン

## 技術スタック

- **フレームワーク**: Ruby on Rails 8.1
- **データベース**: PostgreSQL
- **フロントエンド**: Hotwire (Turbo, Stimulus), Tailwind CSS
- **認証**: Devise
- **デプロイ**: Kamal, Docker
- **その他**: Solid Cache, Solid Queue, Solid Cable

## セットアップ

### 必要条件

- Ruby 3.4.8
- Docker（PostgreSQL 用）
- Node.js（Tailwind CSS ビルド用）

### ローカル起動

```bash
git clone https://github.com/sp8783/vsmobile-kgy.git
cd vsmobile-kgy
bundle install
docker compose up -d        # PostgreSQL を起動（ポート 5433）
bin/setup                   # DB の準備とサンプルデータの作成をして、開発サーバーを起動
```

2 回目以降は `bin/dev` で起動します。起動時に機体マスタ（`db/data/units.json`）が自動で反映されます。

### サンプルデータ

初回の `bin/setup` で、ローカル確認用のサンプルデータが作られます。

- ログイン: `sample_a` 〜 `sample_f`（パスワード `password`）、管理者は `admin`（パスワード `password`）
- 過去のイベント 3 件（最後まで記録済みのローテーションと、詳細統計つきの試合）、開催中のイベント 1 件（入力済み・未入力・スキップ・現在・予定の試合が揃ったローテーション）、これから開催するイベント 2 件（明日・1週間後）
- お気に入り機体の数がユーザーごとに異なる（18 機・10 機・6 機・3 機・1 機・0 機）

データを最初の状態に戻すときは、次を実行します。開発用 DB のデータはすべて消えます（`bin/db-pull` で取り込んだデータも消えます）。

```bash
bin/rails dev:sample_data
```

機体は、その時点の機体マスタから選ばれます。機体が増えても、作り直しは必須ではありません。

#### テスト用の Discord の設定

`config/discord.local.yml.example` を `config/discord.local.yml` にコピーし、テスト用の Webhook URL とフォーラムの記事の URL を書いておくと、サンプルデータの作成時に設定されます（Git の管理対象外）。

- `webhooks.default` の Webhook がすべての投稿先に使われます。投稿先ごとに書くと、そちらが優先されます
- イベントフォーラム（`webhooks.event_forum`）には、フォーラムのチャンネルで作った Webhook が必要です
- `event_thread_url` は、これから開催するサンプルのイベント（明日・1週間後）の「Discord フォーラムスレッド URL」に入ります。サンプルデータを作ったあと `bin/rails runner 'EventReminderJob.perform_now(now: Time.current.change(hour: 8))'` を実行すると、前日・1週間前のリマインドと事前準備のお願いを試せます（投稿文の初期設定の時刻 8 時として実行します。一度送った投稿は、サンプルデータを作り直すまで再び送りません）
- 本番の Webhook は書かないでください。`bin/db-pull` で本番のデータを取り込んだ場合も、本番の Webhook が入るので注意してください

## デプロイ

Kamal を使用します。詳細は `config/deploy.yml` を参照してください。

main への push（リリースブランチのマージ）で CI が成功すると、GitHub Actions（`.github/workflows/deploy.yml`）が自動でデプロイします。Actions の画面から手動で実行することもできます。自動デプロイには、GitHub の `production` Environment に以下の Secrets が必要です（main ブランチからのみ利用可）：

- `DEPLOY_SSH_KEY`（デプロイ専用の SSH 秘密鍵）、`DEPLOY_KNOWN_HOSTS`（サーバーのホスト鍵）
- `RAILS_MASTER_KEY`、`KAMAL_REGISTRY_PASSWORD`、`POSTGRES_PASSWORD`、`VSMOBILE_API_TOKEN`、`KAMAL_GITHUB_TOKEN`

手元からデプロイする場合：

```bash
# 初回のみ（サーバー・DB コンテナの初期化）
kamal setup
kamal accessory boot db

# 通常デプロイ
kamal deploy

# ログ確認
kamal logs
```

`.kamal/secrets` に以下のシークレットが必要です：

- `RAILS_MASTER_KEY`
- `KAMAL_REGISTRY_PASSWORD`
- `POSTGRES_PASSWORD`
- `VSMOBILE_API_TOKEN`
- `GITHUB_TOKEN`

## 機体マスタの更新

機体マスタは `db/data/units.json` と `public/mobile_suits/` の画像を情報源とし、[exvs2ib-wiki-scraper](https://github.com/sp8783/exvs2ib-wiki-scraper) の出力（`output/units.json`・`output/images/`）で更新します。

- 画像名は `{WikiのページID}_{機体名}.png`。機体が追加されても既存の画像名は変わりません
- 反映は `bin/rails mobile_suits:sync` が Wiki のページ ID で突き合わせて行います（何度実行しても同じ結果）。本番ではアプリ起動時に、開発環境では `bin/dev` の起動時に自動実行されるため、手で実行する必要はありません
- 情報解禁済み・未実装の機体は、`config/mobile_suits.yml` の `exclude_page_ids` で除外します

### 機体データの更新確認（自動）

GitHub Actions「機体データの更新確認」が、毎日 5:00（日本時間）に Wiki から全機体を取り直し、アプリが使う項目（機体名・コスト・シリーズ・耐久値・BD回数・赤ロック距離・画像）に変化があれば、機体データ更新の PR を作ります。

- 開発中のリリースブランチ（最新のタグより新しい `release/vX.Y.Z`）があれば、そのブランチ向けの PR（そのリリースに含める）。なければ、main から次のパッチ版の `release/vX.Y.Z` を切り、告知文つきのリリース PR を作ります
- 開いている PR は常に 1 つで、変化が見つかるたびに作り直します。新しい機体の画像・耐久値・BD回数・赤ロック距離が欠けている間は下書きです
- 開発中のリリースを待たずに出したいときは、Actions の画面から「Run workflow」で「単独で出す」を選びます（相乗りの PR を閉じ、単独リリースの PR を作ります）
- マージは手で行います（Wiki には、まだゲームで使えない機体が先に載ることがあるため）
- PR の作成には、リポジトリの Secret `MOBILE_SUITS_UPDATE_TOKEN`（Fine-grained PAT。vsmobile-kgy の Contents・Pull requests・Issues の書き込み）を使います

手元で取り直すときは、スクレイパーを置いた場所を指定して実行します（Wiki へのアクセスは約 250 ページ・約 5 分）。

```bash
SCRAPER_DIR=../exvs2ib-wiki-scraper bin/rails mobile_suits:refresh
```

## リリース告知

`config/release_notes/v{x.y.z}.yml` に告知文を置くと、そのバージョンのデプロイ後の起動時に、アプリ内お知らせの公開と Discord への投稿が自動で行われます（告知済みのバージョンは `release_announcements` に記録され、二重に告知しません）。

```yaml
title: "✨ v2.4.0 リリース！ ..."   # アプリ内お知らせのタイトル
body: |                           # アプリ内お知らせの本文（Markdown。絵文字は Unicode）
  今回は…
discord: |                        # Discord の本文（:shortcode: 可、2,000 文字以内）。省略すると Discord には投稿しない
  @everyone
  …
```

- Discord の投稿先は管理画面「Discord チャンネル設定」の「リリース告知」で設定します
- Discord への投稿に失敗した場合は、告知の作成から 3 日以内であれば次回の起動時に再送します

## リリース後の作業（自動）

リリース PR（`release/vX.Y.Z` → main）のデプロイが成功すると、Deploy ワークフローの `finalize` が次を行います（hotfix など、リリース PR 以外のデプロイでは何もしません）。

- annotated tag `vX.Y.Z` と GitHub Release（Latest）を作る。中身はリリース PR 本文の「## 主な変更」の箇条書き（タグのメッセージからは `(#123)` の PR 番号を外す）
- そのリリースに含まれる Issue（リリースブランチにマージした PR とリリース PR の `Closes #N`）を閉じる
- GitHub Project のステータスを Done にする（Secret `MOBILE_SUITS_UPDATE_TOKEN` に Projects の書き込みがあるとき）

何度実行しても、済んだ作業はやり直しません。失敗したときは Deploy ワークフローの `finalize` を再実行するか、`SHA=<マージコミット> GITHUB_REPOSITORY=sp8783/vsmobile-kgy bin/rails release:finalize` を実行します。

## ライセンス

[MIT License](LICENSE)
