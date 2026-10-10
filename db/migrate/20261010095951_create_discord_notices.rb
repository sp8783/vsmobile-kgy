class CreateDiscordNotices < ActiveRecord::Migration[8.1]
  def change
    create_table :discord_notices do |t|
      t.string :kind, null: false
      t.boolean :enabled, null: false, default: true
      t.text :body, null: false
      t.jsonb :timings, null: false, default: []
      t.timestamps
    end
    add_index :discord_notices, :kind, unique: true

    create_table :discord_notice_deliveries do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.integer :days_before, null: false
      t.datetime :sent_at, null: false
      t.timestamps
    end
    add_index :discord_notice_deliveries, [ :event_id, :kind, :days_before ], unique: true, name: "index_discord_notice_deliveries_uniqueness"
  end
end
