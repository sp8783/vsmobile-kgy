class AddForeignKeyFromMatchesToRotationMatches < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :matches, :rotation_matches, column: :rotation_match_id
  end
end
