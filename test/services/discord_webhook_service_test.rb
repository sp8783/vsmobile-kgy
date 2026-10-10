require "test_helper"

class DiscordWebhookServiceTest < ActiveSupport::TestCase
  test "投稿先が未設定なら投稿せずに false を返す" do
    assert_equal false, DiscordWebhookService.post(purpose: "release", message: "告知")
  end
end
