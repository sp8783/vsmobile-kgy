class CreateReleaseAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :release_announcements do |t|
      t.string :version, null: false
      t.references :announcement, foreign_key: { on_delete: :nullify }
      t.datetime :discord_posted_at
      t.timestamps
    end
    add_index :release_announcements, :version, unique: true
  end
end
