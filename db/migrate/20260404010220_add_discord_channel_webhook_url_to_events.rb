class AddDiscordChannelWebhookUrlToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :discord_channel_webhook_url, :string
  end
end
