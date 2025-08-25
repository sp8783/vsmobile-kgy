class CreateRotationTemplateMatches < ActiveRecord::Migration[8.0]
  def change
    create_table :rotation_template_matches do |t|
      t.references :rotation_template, null: false, foreign_key: true
      t.integer :order
      t.references :team1_user1, null: false, foreign_key: { to_table: :users }
      t.references :team1_user2, null: false, foreign_key: { to_table: :users }
      t.references :team2_user1, null: false, foreign_key: { to_table: :users }
      t.references :team2_user2, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
