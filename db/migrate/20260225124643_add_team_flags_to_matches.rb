class AddTeamFlagsToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :team1_ex_overlimit_before_end, :boolean
    add_column :matches, :team2_ex_overlimit_before_end, :boolean
  end
end
