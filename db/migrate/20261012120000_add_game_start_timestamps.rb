class AddGameStartTimestamps < ActiveRecord::Migration[8.1]
  def change
    # VS.モバイルの試合の開始時刻（統計スクレイピングの match_ts）
    add_column :matches, :game_started_at, :datetime
    # 1試合目が配信の何秒目か（試合の開始時刻から全試合のタイムスタンプを計算する基準）
    add_column :events, :first_match_video_timestamp, :integer

    # 統計スクレイピングで届いた試合ごとのデータ（加工せずにそのまま残す）
    create_table :match_stats_payloads do |t|
      t.references :match, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.jsonb :payload, null: false
      t.timestamps
    end
  end
end
