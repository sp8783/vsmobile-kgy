class MobileSuit < ApplicationRecord
  has_many :match_players, dependent: :destroy

  validates :name, presence: true
  validates :cost, inclusion: { in: [3000, 2500, 2000, 1500],
                                message: "%{value}は存在しないコストです" }
  validates :series, presence: true
end
