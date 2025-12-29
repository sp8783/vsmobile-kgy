class CreateRotations < ActiveRecord::Migration[8.1]
  def change
    create_table :rotations do |t|
      t.references :event, null: false, foreign_key: true
      t.string :name, null: false
      t.bigint :base_rotation_id
      t.integer :round_number, null: false, default: 1
      t.integer :current_match_index, null: false, default: 0
      t.boolean :is_active, null: false, default: false

      t.timestamps
    end

    add_index :rotations, :base_rotation_id
    add_index :rotations, [:event_id, :is_active]
    add_foreign_key :rotations, :rotations, column: :base_rotation_id
  end
end
