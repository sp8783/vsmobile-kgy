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

  test "投稿に失敗したときのログに Webhook の URL を出さない" do
    logged = with_captured_log do
      # ホストのない URL は接続する前に ArgumentError になる（ネットワークに出ない）
      DiscordWebhookService.post_to_webhook_url(url: "https:///api/webhooks/1/secret-token", message: "告知")
    end

    assert_match "[DiscordWebhookService] Failed to post_to_webhook_url: ArgumentError", logged
    assert_no_match "secret-token", logged
  end

  private

  def with_captured_log
    io = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end
end
