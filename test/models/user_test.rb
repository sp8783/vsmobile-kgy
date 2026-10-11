require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(username: "player_a", nickname: "Aさん", password: "password123")
    @others = %w[b c d].map { |name| User.create!(username: "player_#{name}", nickname: "#{name.upcase}さん", password: "password123") }
    @event = Event.create!(name: "テスト対戦会", held_on: Date.new(2026, 10, 11))
    @filler = suit("ほかの人の機体")
  end

  test "最近使った機体は、最後に使った日時の新しい順に重複なく返す" do
    old, middle, latest = suit("古い機体"), suit("真ん中の機体"), suit("新しい機体")
    play(old, at: 3.days.ago)
    play(middle, at: 2.days.ago)
    play(old, at: 1.day.ago)
    play(latest, at: 1.hour.ago)

    assert_equal [ latest.id, old.id, middle.id ], @user.recent_mobile_suit_ids
  end

  test "お気に入りの機体は最近使った機体に含めない" do
    favorite, other = suit("お気に入りの機体"), suit("ほかの機体")
    @user.user_favorite_suits.create!(slot: 0, mobile_suit: favorite)
    play(other, at: 2.hours.ago)
    play(favorite, at: 1.hour.ago)

    assert_equal [ other.id ], @user.recent_mobile_suit_ids
  end

  test "最近使った機体は最大10機体" do
    suits = (1..11).map { |i| suit("機体#{i}") }
    suits.each_with_index { |s, i| play(s, at: (20 - i).hours.ago) }

    assert_equal User::RECENT_MOBILE_SUITS_LIMIT, @user.recent_mobile_suit_ids.size
    assert_equal suits.last(10).reverse.map(&:id), @user.recent_mobile_suit_ids
  end

  test "試合に出ていなければ最近使った機体はない" do
    assert_empty @user.recent_mobile_suit_ids
  end

  private

  def suit(name)
    MobileSuit.create!(name:, series: "テスト", cost: 3000)
  end

  def play(mobile_suit, at:)
    match = @event.matches.build(played_at: at, winning_team: 1)
    match.match_players.build(user: @user, mobile_suit:, position: 1, team_number: 1)
    @others.each.with_index(2) do |user, position|
      match.match_players.build(user:, mobile_suit: @filler, position:, team_number: position <= 2 ? 1 : 2)
    end
    match.save!
  end
end
