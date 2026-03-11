class ChangeSpecColumnsStringInMobileSuits < ActiveRecord::Migration[8.1]
  def change
    change_column :mobile_suits, :bd_count, :string
    change_column :mobile_suits, :red_lock_range, :string
  end
end
