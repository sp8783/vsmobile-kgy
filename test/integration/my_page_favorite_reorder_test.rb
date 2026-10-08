require "test_helper"

class MyPageFavoriteReorderTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(username: "reorder_user", nickname: "並び替え", password: "password123")
    @suits = [ 3000, 2500, 2000 ].each_with_index.map do |cost, i|
      MobileSuit.create!(name: "機体#{i}", series: "テスト", cost: cost, position: i)
    end
    sign_in @user
  end

  test "並び替えモードに、現在の順で使用回数つきの枠を表示する" do
    favorite(@suits[0], @suits[1], @suits[2])
    play(@suits[1], times: 2)

    get my_page_path

    assert_select "button[data-action='click->favorite-reorder#start']", text: "並び替え"
    assert_select "[data-favorite-reorder-target='list'][hidden]" do
      assert_select ".fav-rtile", count: 3
      assert_select ".fav-rtile:first-child[data-suit-id='#{@suits[0].id}'] [data-slot-label]", text: "M"
      assert_select ".fav-rtile[data-suit-id='#{@suits[1].id}'][data-usage='2'] .fav-rusage", text: "2戦"
      assert_select ".fav-rtile[data-suit-id='#{@suits[2].id}'][data-cost='2000']"
    end
    assert_select "[data-favorite-reorder-target='sortBar'][hidden] button", text: /コスト順|使用回数順/, count: 2
    assert_select "[data-favorite-reorder-target='editActions'][hidden] button", text: "保存する"
  end

  test "お気に入りが1機以下なら「並び替え」は出さない" do
    favorite(@suits[0])

    get my_page_path

    assert_select "button[data-action='click->favorite-reorder#start']", count: 0
    assert_select "button[data-action='click->favorite-picker#open']", text: /機体を選ぶ/
  end

  test "保存した並び順でスロットが入れ替わる" do
    favorite(@suits[0], @suits[1], @suits[2])

    post bulk_update_user_favorite_suits_path, params: { mobile_suit_ids: [ @suits[2].id, @suits[0].id, @suits[1].id ] }

    assert_redirected_to my_page_path
    assert_equal [ @suits[2].id, @suits[0].id, @suits[1].id ], @user.user_favorite_suits.order(:slot).pluck(:mobile_suit_id)
  end

  private

  def favorite(*suits)
    suits.each_with_index { |suit, slot| @user.user_favorite_suits.create!(mobile_suit: suit, slot: slot) }
  end

  def play(suit, times:)
    others = 3.times.map { |i| User.create!(username: "other_#{suit.id}_#{i}", nickname: "他#{i}", password: "password123") }
    event = Event.create!(name: "テスト", held_on: Date.new(2026, 10, 11))
    times.times do
      match = event.matches.build(played_at: Time.current, winning_team: 1)
      [ @user, *others ].each_with_index do |user, i|
        match.match_players.build(user: user, mobile_suit: suit, team_number: i < 2 ? 1 : 2, position: i + 1)
      end
      match.save!
    end
  end
end
