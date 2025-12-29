class Rotation < ApplicationRecord
  # Associations
  belongs_to :event
  belongs_to :base_rotation, class_name: 'Rotation', optional: true
  has_many :derived_rotations, class_name: 'Rotation', foreign_key: 'base_rotation_id', dependent: :nullify
  has_many :rotation_matches, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :round_number, presence: true, numericality: { greater_than: 0 }
  validates :current_match_index, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
