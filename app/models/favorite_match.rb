class FavoriteMatch < ApplicationRecord
  belongs_to :user
  belongs_to :match

  validates :match_id, uniqueness: { scope: :user_id }
end
