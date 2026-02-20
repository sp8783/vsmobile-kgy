class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.datetime :published_at, null: false
      t.datetime :expires_at
      t.boolean :is_active, null: false, default: false

      t.timestamps
    end
  end
end
