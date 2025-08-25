class CreateMatchPlayers < ActiveRecord::Migration[8.0]
  def change
    create_table :match_players do |t|
      t.references :match, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: { to_table: :users }
      t.references :team, null: false, foreign_key: true
      t.references :mobile_suit, null: false, foreign_key: true

      t.timestamps
    end
  end
end
