class AddStatsToMatchPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :match_players, :match_rank, :integer
    add_column :match_players, :score, :integer
    add_column :match_players, :kills, :integer
    add_column :match_players, :deaths, :integer
    add_column :match_players, :damage_dealt, :integer
    add_column :match_players, :damage_received, :integer
    add_column :match_players, :exburst_damage, :integer
    add_column :match_players, :exburst_count, :integer
    add_column :match_players, :exburst_deaths, :integer
    add_column :match_players, :ex_overlimit_activated, :boolean
  end
end
