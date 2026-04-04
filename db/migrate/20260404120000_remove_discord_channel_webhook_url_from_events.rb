class RemoveDiscordChannelWebhookUrlFromEvents < ActiveRecord::Migration[8.1]
  def change
    remove_column :events, :discord_channel_webhook_url, :string
  end
end
