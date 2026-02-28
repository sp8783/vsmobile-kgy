class AddExAvailableDeathsToMatchPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :match_players, :last_death_ex_available, :boolean
  end
end
