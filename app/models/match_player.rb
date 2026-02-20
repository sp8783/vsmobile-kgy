class MatchPlayer < ApplicationRecord
  # Associations
  belongs_to :match
  belongs_to :user
  belongs_to :mobile_suit

  # Validations
  validates :team_number, presence: true, inclusion: { in: [ 1, 2 ] }
  validates :position, presence: true, inclusion: { in: [ 1, 2, 3, 4 ] }
  validates :position, uniqueness: { scope: :match_id }
end
