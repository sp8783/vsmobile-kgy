require "test_helper"

# イベントの配信 URL を Discord に投稿するボタン
class EventBroadcastToDiscordTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(username: "admin_user", nickname: "管理者", password: "password123", is_admin: true)
    @event = Event.create!(name: "テスト対戦会", held_on: Date.new(2026, 11, 7), broadcast_url: "https://www.youtube.com/watch?v=test")
  end

  test "投稿先が未設定などで投稿に失敗したら、失敗したことを知らせる" do
    post post_broadcast_to_discord_event_path(@event)

    assert_redirected_to event_path(@event)
    assert_match "Discord への投稿に失敗しました", flash[:alert]
  end

  test "配信 URL がなければ投稿しない" do
    @event.update!(broadcast_url: nil)

    post post_broadcast_to_discord_event_path(@event)

    assert_equal "配信URLが設定されていません。", flash[:alert]
  end
end
