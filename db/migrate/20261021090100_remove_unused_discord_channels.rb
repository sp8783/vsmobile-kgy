class RemoveUnusedDiscordChannels < ActiveRecord::Migration[8.1]
  # 使っていなかった投稿先（タイムスタンプ解析結果・統計スクレイピング結果）の設定を消す。
  # 統計・タイムスタンプの登録は、イベントの Discord フォーラムの記事に知らせる形にした
  def up
    execute "DELETE FROM discord_channels WHERE purpose IN ('timestamp_result', 'stats_result')"
  end

  def down
    # 消した設定は戻せない
  end
end
