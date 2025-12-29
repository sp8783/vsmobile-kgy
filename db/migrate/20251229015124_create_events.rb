class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :name, null: false
      t.date :held_on, null: false
      t.text :description

      t.timestamps
    end

    add_index :events, :held_on
  end
end
