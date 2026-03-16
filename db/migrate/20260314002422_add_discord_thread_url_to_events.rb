class AddDiscordThreadUrlToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :discord_thread_url, :string
  end
end
