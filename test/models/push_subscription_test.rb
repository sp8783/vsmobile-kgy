require "test_helper"

class PushSubscriptionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(username: "player_a", nickname: "太郎さん", password: "password123")
  end

  test "endpoint は https の URL だけ受け付ける" do
    assert @user.push_subscriptions.build(endpoint: "https://push.example.com/1", p256dh_key: "key", auth_key: "auth").valid?

    subscription = @user.push_subscriptions.build(endpoint: "http://10.0.0.1/internal", p256dh_key: "key", auth_key: "auth")
    assert_not subscription.valid?
    assert_equal [ "Endpointは https:// で始まる URL を指定してください" ], subscription.errors.full_messages
  end
end
