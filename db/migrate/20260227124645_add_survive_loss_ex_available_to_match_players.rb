class AddSurviveLossExAvailableToMatchPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :match_players, :survive_loss_ex_available, :boolean
  end
end
