class RotationTemplateMatch < ApplicationRecord
  belongs_to :rotation_template
  belongs_to :team1_player1, class_name: "User"
  belongs_to :team1_player2, class_name: "User"
  belongs_to :team2_player1, class_name: "User"
  belongs_to :team2_player2, class_name: "User"

  validates :order, numericality: { only_integer: true, greater_than: 0 }
end
