class AddSurvivalTimesToMatchPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :match_players, :survival_times, :jsonb
  end
end
