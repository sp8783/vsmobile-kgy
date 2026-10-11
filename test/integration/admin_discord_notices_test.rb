require "test_helper"

class AdminDiscordNoticesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(username: "admin_user", nickname: "管理者", password: "password123", is_admin: true)
  end

  test "投稿文の画面に、リマインドと事前準備のお願いを今の設定で表示する" do
    get admin_discord_notices_path

    assert_response :success
    assert_select "nav.st-tabs a.on", text: "投稿文"
    assert_select "form.dn-card", 2
    assert_select "form[action=?] [data-discord-notice-target=timings] [data-discord-notice-target=timing]", admin_discord_notice_path("reminder"), 2
    assert_select "form[action=?] [data-discord-notice-target=timings] [data-discord-notice-target=timing]", admin_discord_notice_path("preparation"), 1
  end

  test "リマインドの文面と送るタイミングを保存できる" do
    patch admin_discord_notice_path("reminder"), params: { discord_notice: {
      enabled: "1", body: "{いつ}の開催です",
      timings: [ { days_before: "3", hour: "21" }, { days_before: "1", hour: "8" } ]
    } }

    assert_redirected_to admin_discord_notices_path
    notice = DiscordNotice.find_by!(kind: "reminder")
    assert_equal "{いつ}の開催です", notice.body
    assert_equal [ [ 3, 21 ], [ 1, 8 ] ], notice.timing_list.map { |timing| [ timing.days_before, timing.hour ] }
  end

  test "リマインドのタイミングをすべて消して保存できる" do
    patch admin_discord_notice_path("reminder"), params: { discord_notice: { enabled: "1", body: "本文" } }

    assert_redirected_to admin_discord_notices_path
    assert_empty DiscordNotice.find_by!(kind: "reminder").timings
  end

  test "送らない設定にできる" do
    patch admin_discord_notice_path("preparation"), params: { discord_notice: { enabled: "0", body: "本文", timings: [ { days_before: "1", hour: "8" } ] } }

    assert_not DiscordNotice.find_by!(kind: "preparation").enabled?
  end

  test "同じ日数のタイミングがあると保存せず、理由を表示する" do
    patch admin_discord_notice_path("reminder"), params: { discord_notice: {
      enabled: "1", body: "本文", timings: [ { days_before: "1", hour: "8" }, { days_before: "1", hour: "20" } ]
    } }

    assert_response :unprocessable_entity
    assert_select ".dn-warn", text: /同じ日数/
    assert DiscordNotice.none?
  end

  test "Discord 設定の投稿先の画面にもタブがある" do
    get admin_discord_channels_path

    assert_select "nav.st-tabs a.on", text: "投稿先"
  end
end
