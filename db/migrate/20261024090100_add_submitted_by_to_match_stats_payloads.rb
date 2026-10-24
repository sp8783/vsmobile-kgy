class AddSubmittedByToMatchStatsPayloads < ActiveRecord::Migration[8.1]
  # 試合ごとの統計データを誰のブックマークレットから受け取ったか（GitHub Actions の一括取得は nil）と、受け取った日時
  def change
    add_reference :match_stats_payloads, :submitted_by, foreign_key: { to_table: :users, on_delete: :nullify }, null: true
    add_column :match_stats_payloads, :submitted_at, :datetime
  end
end
