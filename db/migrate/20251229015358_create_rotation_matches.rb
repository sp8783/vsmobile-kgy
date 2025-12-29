class CreateRotationMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :rotation_matches do |t|
      t.references :rotation, null: false, foreign_key: true
      t.integer :match_index, null: false
      t.bigint :team1_player1_id, null: false
      t.bigint :team1_player2_id, null: false
      t.bigint :team2_player1_id, null: false
      t.bigint :team2_player2_id, null: false
      t.bigint :match_id

      t.timestamps
    end

    add_index :rotation_matches, [:rotation_id, :match_index], unique: true
    add_index :rotation_matches, :match_id
    add_foreign_key :rotation_matches, :users, column: :team1_player1_id
    add_foreign_key :rotation_matches, :users, column: :team1_player2_id
    add_foreign_key :rotation_matches, :users, column: :team2_player1_id
    add_foreign_key :rotation_matches, :users, column: :team2_player2_id
    add_foreign_key :rotation_matches, :matches, column: :match_id
  end
end
