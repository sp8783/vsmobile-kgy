require "test_helper"

class MyPageFavoritePickerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(username: "picker_user", nickname: "ピッカー", password: "password123")
    @suits = 3.times.map { |i| MobileSuit.create!(name: "機体#{i}", series: "テスト", cost: 3000, position: i) }
    @suits.first(2).each_with_index { |suit, slot| @user.user_favorite_suits.create!(mobile_suit: suit, slot: slot) }
    sign_in @user
  end

  test "ピッカーにトレイはなく、「選択中」タブから選んだ機体を絞り込める" do
    get my_page_path

    assert_response :success
    assert_select ".pk-tray", count: 0
    assert_select ".pk-head h2", text: "お気に入り機体を選ぶ"
    assert_select "button.pk-costtab.sel[data-cost='selected']", text: /選択中/
    assert_select "[data-favorite-picker-target='selectedHint'][hidden]"
    assert_select "[data-suit-wrapper][data-suit-id='#{@suits.first.id}']"
    assert_select ".pk-cell [data-slot-label]", count: @suits.size
    assert_select "button[data-favorite-picker-target='saveBtn']", text: "保存する"
  end

  test "マイページのピッカーを開くボタンは「機体を選ぶ」" do
    get my_page_path

    assert_select "button[data-action='click->favorite-picker#open']", text: /機体を選ぶ/
  end
end
