class CreateMobileSuits < ActiveRecord::Migration[8.0]
  def change
    create_table :mobile_suits do |t|
      t.string :name
      t.integer :cost
      t.string :series

      t.timestamps
    end
  end
end
