class CreateMobileSuits < ActiveRecord::Migration[8.1]
  def change
    create_table :mobile_suits do |t|
      t.string :name, null: false
      t.string :series, null: false
      t.integer :cost, null: false

      t.timestamps
    end

    add_index :mobile_suits, :name
    add_index :mobile_suits, :cost
  end
end
