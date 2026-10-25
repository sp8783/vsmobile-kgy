# 機体マスタ

機体マスタは `db/data/units.json` と `public/mobile_suits/` の画像を情報源とし、[exvs2ib-wiki-scraper](https://github.com/sp8783/exvs2ib-wiki-scraper) の出力（`output/units.json`・`output/images/`）で更新します。

- 画像名は `{WikiのページID}_{機体名}.png`。機体が追加されても既存の画像名は変わりません
- 反映は `bin/rails mobile_suits:sync` が Wiki のページ ID で突き合わせて行います（何度実行しても同じ結果）。本番ではアプリ起動時に、開発環境では `bin/dev` の起動時に自動実行されるため、手で実行する必要はありません
- 情報解禁済み・未実装の機体は、`config/mobile_suits.yml` の `exclude_page_ids` で除外します

## 更新確認（自動）

GitHub Actions「機体データの更新確認」（`.github/workflows/mobile-suits-update.yml`）が、毎日 5:00（日本時間）に Wiki から全機体を取り直し、アプリが使う項目（機体名・コスト・シリーズ・耐久値・BD回数・赤ロック距離・画像）に変化があれば、機体データ更新の PR を作ります。

- 開発中のリリースブランチ（最新のタグより新しい `release/vX.Y.Z`）があれば、そのブランチ向けの PR（そのリリースに含める）。なければ、main から次のパッチ版の `release/vX.Y.Z` を切り、告知文つきのリリース PR を作ります
- 開いている PR は常に 1 つで、変化が見つかるたびに作り直します。新しい機体の画像・耐久値・BD回数・赤ロック距離が欠けている間は下書きです
- 開発中のリリースを待たずに出したいときは、Actions の画面から「Run workflow」で「単独で出す」を選びます（相乗りの PR を閉じ、単独リリースの PR を作ります）
- マージは手で行います（Wiki には、まだゲームで使えない機体が先に載ることがあるため）
- PR の作成には、リポジトリの Secret `MOBILE_SUITS_UPDATE_TOKEN`（Fine-grained PAT。vsmobile-kgy の Contents・Pull requests・Issues の書き込み）を使います

実装は `lib/mobile_suit_update/` です。

## 手元で取り直す

スクレイパーを置いた場所を指定して実行します（Wiki へのアクセスは約 250 ページ・約 5 分）。

```bash
SCRAPER_DIR=../exvs2ib-wiki-scraper bin/rails mobile_suits:refresh
```
