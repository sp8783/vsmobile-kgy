class AddStartedAtToRotationMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :rotation_matches, :started_at, :datetime
  end
end
