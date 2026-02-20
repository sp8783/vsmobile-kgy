class Event < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :held_on, presence: true
  validates :broadcast_url, format: { with: /\Ahttps?:\/\//i, message: "は http:// または https:// で始まる URL を入力してください" }, allow_blank: true

  # Associations
  has_many :matches, dependent: :destroy
  has_many :rotations, dependent: :destroy
end
