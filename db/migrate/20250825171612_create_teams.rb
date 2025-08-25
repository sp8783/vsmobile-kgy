class CreateTeams < ActiveRecord::Migration[8.0]
  def change
    create_table :teams do |t|
      t.references :player1, null: false, foreign_key: { to_table: :users }
      t.references :player2, null: false, foreign_key: { to_table: :users }
      t.string :name

      t.timestamps
    end

    
    add_index :teams, [:player1_id, :player2_id], unique: true
  end
end
