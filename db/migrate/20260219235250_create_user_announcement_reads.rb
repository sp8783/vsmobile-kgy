class CreateUserAnnouncementReads < ActiveRecord::Migration[8.1]
  def change
    create_table :user_announcement_reads do |t|
      t.references :user, null: false, foreign_key: true
      t.references :announcement, null: false, foreign_key: true

      t.timestamps
    end
    add_index :user_announcement_reads, [ :user_id, :announcement_id ], unique: true
  end
end
