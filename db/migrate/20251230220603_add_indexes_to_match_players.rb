class AddIndexesToMatchPlayers < ActiveRecord::Migration[8.1]
  def change
    # team_number is frequently used for filtering partners and opponents
    add_index :match_players, :team_number

    # Composite indexes for common query patterns
    add_index :match_players, [ :user_id, :mobile_suit_id ]
    add_index :match_players, [ :match_id, :team_number ]

    # Event-based queries for dashboard statistics
    add_index :matches, [ :event_id, :played_at ]
  end
end
