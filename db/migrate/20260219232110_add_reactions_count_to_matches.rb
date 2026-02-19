class AddReactionsCountToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :reactions_count, :integer, default: 0, null: false
    execute <<~SQL
      UPDATE matches
      SET reactions_count = (
        SELECT COUNT(*) FROM reactions WHERE reactions.match_id = matches.id
      )
    SQL
  end
end
