class CreateDiscordChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :discord_channels do |t|
      t.string :purpose, null: false
      t.string :webhook_url
      t.string :label

      t.timestamps
    end

    add_index :discord_channels, :purpose, unique: true
  end
end
