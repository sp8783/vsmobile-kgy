class CreateRotationTemplateMatches < ActiveRecord::Migration[8.0]
  def change
    create_table :rotation_template_matches do |t|
      t.references :rotation_template, null: false, foreign_key: true
      t.integer :order, null: false
      t.integer :team1_player1_index, null: false
      t.integer :team1_player2_index, null: false
      t.integer :team2_player1_index, null: false
      t.integer :team2_player2_index, null: false

      t.timestamps
    end
  end
end
