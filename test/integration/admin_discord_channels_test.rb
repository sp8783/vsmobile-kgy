require "test_helper"

class AdminDiscordChannelsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(username: "admin_user", nickname: "管理者", password: "password123", is_admin: true)
  end

  test "Discord 設定画面に「リリース告知」の投稿先がある" do
    get admin_discord_channels_path

    assert_response :success
    assert_select "h2, h3, .ui-card", text: /リリース告知/
  end

  test "「リリース告知」の投稿先を保存できる" do
    patch admin_discord_channel_path("release"), params: { discord_channel: { webhook_url: "https://discord.com/api/webhooks/1/abc", label: "#お知らせ" } }

    assert_redirected_to admin_discord_channels_path
    assert_equal "https://discord.com/api/webhooks/1/abc", DiscordChannel.find_by!(purpose: "release").webhook_url
  end
end
