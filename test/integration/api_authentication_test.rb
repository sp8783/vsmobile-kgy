require "test_helper"

# API の Bearer トークン認証
class ApiAuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["VSMOBILE_API_TOKEN"]
    ENV["VSMOBILE_API_TOKEN"] = "test-token"
    @event = Event.create!(name: "テスト対戦会", held_on: Date.new(2026, 10, 11))
  end

  teardown do
    ENV["VSMOBILE_API_TOKEN"] = @previous_token
  end

  test "トークンがなければ 401" do
    post notify_failure_api_event_path(@event), params: { error: "x" }, as: :json

    assert_response :unauthorized
  end

  test "トークンが違えば 401" do
    post notify_failure_api_event_path(@event), params: { error: "x" }, as: :json, headers: { "Authorization" => "Bearer test-toke" }

    assert_response :unauthorized
  end

  test "サーバー側にトークンがなければ、何を送っても 401" do
    ENV["VSMOBILE_API_TOKEN"] = nil

    post notify_failure_api_event_path(@event), params: { error: "x" }, as: :json, headers: { "Authorization" => "Bearer " }

    assert_response :unauthorized
  end

  test "トークンが合えば通る" do
    post notify_failure_api_event_path(@event), params: { error: "x" }, as: :json, headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
  end
end
