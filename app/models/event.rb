class Event < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :held_on, presence: true

  # Associations
  has_many :matches, dependent: :destroy
  has_many :rotations, dependent: :destroy
end
