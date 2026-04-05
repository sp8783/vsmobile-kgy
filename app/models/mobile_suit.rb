class MobileSuit < ApplicationRecord
  scope :catalog_order, -> { order(Arel.sql("position IS NULL, position ASC, cost DESC, name ASC")) }
  scope :position_order, -> { order(:position) }

  # Validations
  validates :name, presence: true
  validates :series, presence: true
  validates :cost, presence: true, inclusion: { in: [ 1000, 1500, 2000, 2500, 3000 ] }

  # Associations
  has_many :match_players, dependent: :restrict_with_error
end
