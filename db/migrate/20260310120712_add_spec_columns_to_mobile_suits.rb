class AddSpecColumnsToMobileSuits < ActiveRecord::Migration[8.1]
  def change
    add_column :mobile_suits, :durability, :integer
    add_column :mobile_suits, :bd_count, :integer
    add_column :mobile_suits, :red_lock_range, :decimal, precision: 5, scale: 2
  end
end
