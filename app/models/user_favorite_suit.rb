class UserFavoriteSuit < ApplicationRecord
  belongs_to :user
  belongs_to :mobile_suit

  MAX_SLOTS = 18
  SLOTS = (0...MAX_SLOTS).freeze
  SLOT_LABELS = { 0 => "メイン" }.merge((1...MAX_SLOTS).index_with { |i| "サブ#{i}" }).freeze

  validates :slot, inclusion: { in: SLOTS }
  validates :slot, uniqueness: { scope: :user_id }
  validates :mobile_suit_id, uniqueness: { scope: :user_id, message: "はすでに別のスロットに設定されています" }
end
