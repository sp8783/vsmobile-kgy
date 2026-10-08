require "test_helper"

class UserFavoriteSuitTest < ActiveSupport::TestCase
  test "allows up to 18 slots" do
    assert_equal 18, UserFavoriteSuit::MAX_SLOTS
    assert_equal (0..17).to_a, UserFavoriteSuit::SLOTS.to_a
    assert_equal "メイン", UserFavoriteSuit::SLOT_LABELS[0]
    assert_equal "サブ17", UserFavoriteSuit::SLOT_LABELS[17]
  end

  test "rejects slots outside the range" do
    assert_empty slot_errors(17)
    assert_not_empty slot_errors(18)
    assert_not_empty slot_errors(-1)
  end

  private

  def slot_errors(slot)
    favorite = UserFavoriteSuit.new(slot: slot)
    favorite.validate
    favorite.errors[:slot]
  end
end
