class AddFirstUnitExburstCountToMatchPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :match_players, :first_unit_exburst_count, :integer
  end
end
