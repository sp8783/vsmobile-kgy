class RotationTemplate < ApplicationRecord
  has_many :rotation_template_matches, dependent: :destroy

  validates :name, presence: true
  validates :player_count, numericality: { only_integer: true, greater_than: 0 }
  validates :match_count, numericality: { only_integer: true, greater_than: 0 }
end
