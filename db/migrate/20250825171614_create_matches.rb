class CreateMatches < ActiveRecord::Migration[8.0]
  def change
    create_table :matches do |t|
      t.references :event, null: false, foreign_key: true
      t.references :team1, null: false, foreign_key: { to_table: :teams }
      t.references :team2, null: false, foreign_key: { to_table: :teams }
      t.references :winner_team, foreign_key: { to_table: :teams }

      t.timestamps
    end
  end
end
