class RotationTemplateMatch < ApplicationRecord
  belongs_to :rotation_template

  validates :order, numericality: { only_integer: true, greater_than: 0 }
  validates :team1_player1_index, :team1_player2_index,
            :team2_player1_index, :team2_player2_index,
            presence: true, numericality: { only_integer: true }
end
