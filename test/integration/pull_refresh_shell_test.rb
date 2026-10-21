require "test_helper"

# スマホの引っ張って更新: トップバーの下の中身だけがスクロールする入れ物と、更新マークの描画
class PullRefreshShellTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "ログイン中は、トップバーの下にスクロールの入れ物と更新マークがある" do
    sign_in User.create!(username: "player", nickname: "プレイヤー", password: "password123")

    get dashboard_path

    assert_response :success
    assert_select ".page-shell[data-controller=pull-refresh]:not(.page-shell--bare)", 1
    assert_select ".page-shell > .nav-topbar", 1
    assert_select ".page-shell > .pr-indicator[data-pull-refresh-target=indicator] svg.pr-spinner", 1
    assert_select ".page-shell > .app-scroll[data-pull-refresh-target=scroller] > main.app-content", 1
  end

  test "スマホで入力欄にフォーカスしても拡大されないよう、viewport で拡大を止める" do
    get new_user_session_path

    assert_select "meta[name=viewport][content=?]", "width=device-width,initial-scale=1,maximum-scale=1"
  end

  test "ログイン前の画面は、トップバーのない入れ物として描く" do
    get new_user_session_path

    assert_response :success
    assert_select ".page-shell.page-shell--bare[data-controller=pull-refresh]", 1
    assert_select ".nav-topbar", 0
    assert_select ".app-scroll > main.app-content--bare", 1
  end
end
