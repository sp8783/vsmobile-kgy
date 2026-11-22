# デプロイ

Kamal を使います。設定は `config/deploy.yml` です。

## 自動デプロイ

main への push（リリースブランチのマージ）で CI が成功すると、GitHub Actions（`.github/workflows/deploy.yml`）が自動でデプロイします。Actions の画面から手動で実行することもできます。

自動デプロイには、GitHub の `production` Environment に以下の Secrets が必要です（main ブランチからのみ利用可）。

- `DEPLOY_SSH_KEY`（デプロイ専用の SSH 秘密鍵）、`DEPLOY_KNOWN_HOSTS`（サーバーのホスト鍵）
- `RAILS_MASTER_KEY`、`KAMAL_REGISTRY_PASSWORD`、`POSTGRES_PASSWORD`、`VSMOBILE_API_TOKEN`、`KAMAL_GITHUB_TOKEN`

起動時に `bin/docker-entrypoint` が `db:prepare`（マイグレーション）、`mobile_suits:sync`（機体マスタの反映）、`release_notes:announce`（リリース告知）を実行します。

## 依存と Ruby の更新（自動）

人手を介さずに main へ入り、そのままデプロイされます。main にはブランチ保護があり、CI の 4 つのチェック（lint / scan_ruby / scan_js / test）が通らないとマージできません。自動の定期実行はすべて **毎日 5:00 JST** に動きます（機体データの更新確認も同じ時刻）。

- **gem・GitHub Actions**: Dependabot が毎日 5:00 JST に確認します。gem は間接依存も対象です。patch / minor の PR は `.github/workflows/dependabot-auto-merge.yml` が CI 後にマージします（major は手で）。脆弱性はリポジトリ設定の Dependabot security updates がスケジュールを待たずに PR を出します
- **Ruby**: GitHub Actions「Ruby の更新確認」（`.github/workflows/ruby-update.yml`、毎日 5:00 JST）が、`ruby/setup-ruby` が入れられて Docker Hub に `ruby:<版>-slim` がある新しい版を見つけると、`.ruby-version`・`Dockerfile`・README・`docs/development.md` と、workflow で SHA 固定している `ruby/setup-ruby` を上げる PR を作ります。patch は自動マージを予約し、minor / major は下書きの PR にします（取り込みと修正は手で。中身は `lib/ruby_update/`）。手元で確かめるだけなら `bin/rails ruby_update:check` です
- PR の作成には、リポジトリの Secret `MOBILE_SUITS_UPDATE_TOKEN`（Fine-grained PAT）を使います（機体データの更新確認と同じ）

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
