class RemoveNameFromRotations < ActiveRecord::Migration[8.1]
  def change
    remove_column :rotations, :name, :string
  end
end
