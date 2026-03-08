class UserFavoriteSuit < ApplicationRecord
  belongs_to :user
  belongs_to :mobile_suit

  MAX_SLOTS = 12
  SLOTS = (0..11).freeze
  SLOT_LABELS = { 0 => "メイン" }.merge((1..11).index_with { |i| "サブ#{i}" }).freeze

  validates :slot, inclusion: { in: SLOTS }
  validates :slot, uniqueness: { scope: :user_id }
  validates :mobile_suit_id, uniqueness: { scope: :user_id, message: "はすでに別のスロットに設定されています" }
end
