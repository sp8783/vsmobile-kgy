class AddPositionToMobileSuits < ActiveRecord::Migration[8.1]
  def change
    add_column :mobile_suits, :position, :integer
  end
end
