require "test_helper"

# 統計ページのユーザー切り替え（view_user_id）。ゲストには許さない
class StatisticsGuestViewTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @player = User.create!(username: "player_a", nickname: "太郎さん", password: "password123")
    @other = User.create!(username: "player_b", nickname: "次郎さん", password: "password123")
    @guest = User.create!(username: "guest", nickname: "ゲスト", password: SecureRandom.hex(16), is_guest: true)
  end

  test "ゲストは view_user_id を付けても個人統計のタブを開けない" do
    sign_in @guest

    get statistics_path(view_user_id: @player.id, tab: "overview")

    assert_redirected_to statistics_path(tab: "highlights")
  end

  test "ゲストは view_user_id を付けても他のプレイヤーの実名を見られない" do
    sign_in @guest

    get statistics_path(view_user_id: @player.id, tab: "highlights")

    assert_response :success
    assert_select ".st-userbar", 0
    assert_no_match @player.nickname, response.body
  end

  test "一般ユーザーは view_user_id で他のプレイヤーの視点に切り替えられる" do
    sign_in @other

    get statistics_path(view_user_id: @player.id, tab: "overview")

    assert_response :success
    assert_select "a.st-chip.on", text: @player.nickname
  end
end
