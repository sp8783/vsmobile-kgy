require "test_helper"

class DiscordWebhookServiceTest < ActiveSupport::TestCase
  test "投稿先が未設定なら投稿せずに false を返す" do
    assert_equal false, DiscordWebhookService.post(purpose: "release", message: "告知")
  end

  test "thread_id を渡すと、Webhook の URL にスレッドの ID を付ける" do
    assert_equal "https://discord.com/api/webhooks/1/abc?thread_id=99", DiscordWebhookService.webhook_url_for("https://discord.com/api/webhooks/1/abc", thread_id: "99")
    assert_equal "https://discord.com/api/webhooks/1/abc?wait=true&thread_id=99", DiscordWebhookService.webhook_url_for("https://discord.com/api/webhooks/1/abc?wait=true", thread_id: "99")
    assert_equal "https://discord.com/api/webhooks/1/abc", DiscordWebhookService.webhook_url_for("https://discord.com/api/webhooks/1/abc")
  end
end
