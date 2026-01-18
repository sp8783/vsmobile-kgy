# VSMobile KGY

KGYコミュニティ向けに開発された、「機動戦士ガンダム エクストリームバーサス2 インフィニットブースト」の対戦会運営を支援するWebアプリケーションです。

ローテーション表の管理、試合結果の記録、戦績統計などの機能を提供します。

## 主な機能

### イベント管理
- 対戦会（イベント）の作成・編集・削除
- イベントごとの試合記録管理

### ローテーション管理
- 4〜8人の参加者からローテーション表を自動生成
- リアルタイムで試合進行状況を共有
- 次の出番までの待ち試合数を表示
- ワンクリックで試合結果を記録

### 戦績・統計
- 個人戦績（勝率、連勝/連敗など）
- イベント別・機体別・パートナー別の詳細統計
- 対面相性マトリクス
- コスト帯分析

### その他
- PWA対応（スマートフォンにインストール可能）
- プッシュ通知（出番が近づくと通知）
- レスポンシブデザイン（モバイル/デスクトップ対応）
- ゲストログイン機能

## 技術スタック

- **フレームワーク**: Ruby on Rails 8.1
- **データベース**: PostgreSQL
- **フロントエンド**: Hotwire (Turbo, Stimulus), Tailwind CSS
- **認証**: Devise
- **デプロイ**: Kamal, Docker
- **その他**: Solid Cache, Solid Queue, Solid Cable

## セットアップ

### 必要条件

- Ruby 3.4.x
- PostgreSQL 16+
- Node.js（Tailwind CSS ビルド用）

### インストール

```bash
# リポジトリをクローン
git clone https://github.com/your-username/vsmobile-kgy.git
cd vsmobile-kgy

# 依存関係をインストール
bundle install

# データベースをセットアップ
bin/rails db:setup

# 開発サーバーを起動
bin/dev
```

### 環境変数

本番環境では以下の環境変数が必要です：

- `RAILS_MASTER_KEY` - credentials の復号化キー
- `DATABASE_URL` - PostgreSQL 接続URL
- `TZ` - タイムゾーン（`Asia/Tokyo` 推奨）

## デプロイ

Kamal を使用してデプロイします。

```bash
# 初回セットアップ
kamal setup

# データベースコンテナを起動（初回デプロイ前に必要）
kamal accessory boot db

# デプロイ
kamal deploy

# ログ確認
kamal app logs
```

設定は `config/deploy.yml` を参照してください。

## 開発

```bash
# 開発サーバー起動（Rails + Tailwind CSS ウォッチ）
bin/dev

# Tailwind CSS のみビルド
bin/rails tailwindcss:build

# コンソール
bin/rails console

# データベースコンソール
bin/rails dbconsole
```

## ライセンス

このプロジェクトは [MIT License](LICENSE) の下で公開されています。
