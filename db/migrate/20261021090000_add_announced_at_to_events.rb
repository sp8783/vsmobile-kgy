class AddAnnouncedAtToEvents < ActiveRecord::Migration[8.1]
  def change
    # 統計・タイムスタンプが全試合そろったことを Discord のフォーラムの記事に知らせた時刻（それぞれ 1 回だけ知らせる）
    add_column :events, :stats_announced_at, :datetime
    add_column :events, :timestamps_announced_at, :datetime
  end
end
