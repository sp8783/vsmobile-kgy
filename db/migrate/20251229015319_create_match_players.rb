class CreateMatchPlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :match_players do |t|
      t.references :match, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :mobile_suit, null: false, foreign_key: true
      t.integer :team_number, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :match_players, [:match_id, :position], unique: true
  end
end
