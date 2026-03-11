class CreateUserFavoriteSuits < ActiveRecord::Migration[8.1]
  def change
    create_table :user_favorite_suits do |t|
      t.references :user, null: false, foreign_key: true
      t.references :mobile_suit, null: false, foreign_key: true
      t.integer :slot, null: false

      t.timestamps
    end

    add_index :user_favorite_suits, [ :user_id, :slot ], unique: true
  end
end
