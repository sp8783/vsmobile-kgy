class CreateFavoriteMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :favorite_matches do |t|
      t.references :user, null: false, foreign_key: true
      t.references :match, null: false, foreign_key: true
      t.timestamps
    end
    add_index :favorite_matches, [ :user_id, :match_id ], unique: true
  end
end
