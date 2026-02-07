class MasterEmoji < ApplicationRecord
  # Associations
  has_many :reactions, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :image_key, presence: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(Arel.sql('position IS NULL, position ASC, created_at ASC')) }

  # Helper method to check if image_key is an asset file
  def asset_image?
    image_key.match?(/\.(png|jpg|jpeg|gif|svg)\z/i)
  end
end
