# デプロイ

Kamal を使います。設定は `config/deploy.yml` です。

## 自動デプロイ

main への push（リリースブランチのマージ）で CI が成功すると、GitHub Actions（`.github/workflows/deploy.yml`）が自動でデプロイします。Actions の画面から手動で実行することもできます。

自動デプロイには、GitHub の `production` Environment に以下の Secrets が必要です（main ブランチからのみ利用可）。

- `DEPLOY_SSH_KEY`（デプロイ専用の SSH 秘密鍵）、`DEPLOY_KNOWN_HOSTS`（サーバーのホスト鍵）
- `RAILS_MASTER_KEY`、`KAMAL_REGISTRY_PASSWORD`、`POSTGRES_PASSWORD`、`VSMOBILE_API_TOKEN`、`KAMAL_GITHUB_TOKEN`

起動時に `bin/docker-entrypoint` が `db:prepare`（マイグレーション）、`mobile_suits:sync`（機体マスタの反映）、`release_notes:announce`（リリース告知）を実行します。

## 手元からデプロイする

```bash
# 初回のみ（サーバー・DB コンテナの初期化）
kamal setup
kamal accessory boot db

# 通常デプロイ
kamal deploy

# ログ確認
kamal logs
```

`.kamal/secrets` に以下のシークレットが必要です。

- `RAILS_MASTER_KEY`
- `KAMAL_REGISTRY_PASSWORD`
- `POSTGRES_PASSWORD`
- `VSMOBILE_API_TOKEN`
- `GITHUB_TOKEN`
