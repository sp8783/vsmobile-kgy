class CreatePushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :endpoint, null: false
      t.string :p256dh_key, null: false
      t.string :auth_key, null: false
      t.string :user_agent
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :push_subscriptions, :endpoint, unique: true
    add_index :push_subscriptions, :last_used_at
  end
end
