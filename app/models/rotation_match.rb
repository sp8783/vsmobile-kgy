class RotationMatch < ApplicationRecord
  # Associations
  belongs_to :rotation
  belongs_to :team1_player1, class_name: "User"
  belongs_to :team1_player2, class_name: "User"
  belongs_to :team2_player1, class_name: "User"
  belongs_to :team2_player2, class_name: "User"
  belongs_to :match, optional: true
  has_one :match_result, class_name: "Match", foreign_key: "rotation_match_id", dependent: :nullify

  # Validations
  validates :match_index, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :match_index, uniqueness: { scope: :rotation_id }

  # Get all players in this match
  def players
    [ team1_player1, team1_player2, team2_player1, team2_player2 ]
  end
end
