class MatchPlayer < ApplicationRecord
  belongs_to :match
  belongs_to :player, class_name: "User"
  belongs_to :team
  belongs_to :mobile_suit

  validates :match, presence: true
  validates :player, presence: true
  validates :team, presence: true
  validates :mobile_suit, presence: true
end
