class CreateMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :matches do |t|
      t.references :event, null: false, foreign_key: true
      t.bigint :rotation_match_id
      t.datetime :played_at, null: false
      t.integer :winning_team, null: false

      t.timestamps
    end

    add_index :matches, :rotation_match_id
    add_index :matches, :played_at
  end
end
