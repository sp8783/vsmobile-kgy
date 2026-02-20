class CreateReactions < ActiveRecord::Migration[8.1]
  def change
    create_table :reactions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :match, null: false, foreign_key: true
      t.references :master_emoji, null: false, foreign_key: true

      t.timestamps
    end

    add_index :reactions, [ :user_id, :match_id, :master_emoji_id ], unique: true, name: 'index_reactions_unique'
  end
end
