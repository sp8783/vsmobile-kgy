class Match < ApplicationRecord
  # Associations
  belongs_to :event
  belongs_to :rotation_match, optional: true
  has_many :match_players, dependent: :destroy

  # Validations
  validates :played_at, presence: true
  validates :winning_team, presence: true, inclusion: { in: [1, 2] }
  validates :match_players, length: { is: 4 }
end
