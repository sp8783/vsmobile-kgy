class Reaction < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :match, counter_cache: true
  belongs_to :master_emoji

  # Validations
  validates :user_id, uniqueness: { scope: [ :match_id, :master_emoji_id ], message: "は同じ試合に同じスタンプで複数回リアクションできません" }
end
