# VS.Mobile for KGY

KGYコミュニティ向けの対戦会運営支援Webアプリです。「機動戦士ガンダム エクストリームバーサス2 インフィニットブースト」のローテーション表管理・試合記録・戦績統計を提供します。

## 機能

**対戦会管理**
- 対戦会の作成・編集と、4〜8人からのローテーション表自動生成（スロットはランダム割り当て・次ラウンド再生成に対応）
- 公平性チェック画面で参加者ごとの登録対戦数・配信台経験を確認しながら進行
- リアルタイムの試合進行共有・ワンクリック結果記録
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
- Webhook経由のイベントリマインド自動送信（7日前・前日）、前日リマインドにはアプリ準備メッセージも同時投稿
- リマインド先は管理画面のグローバル設定で一元管理
- 指定チャンネルへの配信URL手動投稿

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
bin/rails db:setup
bin/dev
```

## デプロイ

Kamal を使用します。詳細は `config/deploy.yml` を参照してください。

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

## ライセンス

[MIT License](LICENSE)
