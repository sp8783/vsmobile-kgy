require "test_helper"

class ApiEventsNotifyFailureTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @previous_token = ENV["VSMOBILE_API_TOKEN"]
    ENV["VSMOBILE_API_TOKEN"] = "test-token"
    @event = Event.create!(name: "テスト対戦会", held_on: Date.new(2026, 10, 11))
    admin = User.create!(username: "admin_user", nickname: "管理者", password: "password123", is_admin: true)
    admin.push_subscriptions.create!(endpoint: "https://push.example.com/1", p256dh_key: "key", auth_key: "auth")
  end

  teardown do
    ENV["VSMOBILE_API_TOKEN"] = @previous_token
  end

  test "統計のスクレイピングの失敗は「統計スクレイピング失敗」で管理者に通知する" do
    post_failure(source: "stats", error: "API への送信に失敗しました。")

    assert_response :success
    assert_equal [ "統計スクレイピング失敗", "テスト対戦会: API への送信に失敗しました。" ], notified.values_at("title", "body")
  end

  test "どのツールの失敗か指定がなければ、タイムスタンプ解析の失敗として通知する" do
    post_failure(error: "動画の解析に失敗しました。")

    assert_response :success
    assert_equal "タイムスタンプ登録失敗", notified["title"]
  end

  private

  def post_failure(**params)
    post "/api/events/#{@event.id}/notify_failure", params: params.to_json,
         headers: { "Authorization" => "Bearer test-token", "Content-Type" => "application/json" }
  end

  def notified
    job = enqueued_jobs.select { |candidate| candidate["job_class"] == "SendPushNotificationJob" }.sole
    ActiveJob::Arguments.deserialize(job["arguments"]).first.stringify_keys
  end
end
