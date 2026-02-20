class MobileSuit < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :series, presence: true
  validates :cost, presence: true, inclusion: { in: [ 1000, 1500, 2000, 2500, 3000 ] }

  # Associations
  has_many :match_players, dependent: :restrict_with_error
end
