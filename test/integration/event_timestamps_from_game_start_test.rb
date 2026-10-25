require "test_helper"

class EventTimestampsFromGameStartTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include Devise::Test::IntegrationHelpers

  # 1試合目の開始時刻（2026-11-07 10:12:05 JST）と、2・3試合目の開始時刻（1試合目からの秒数）
  FIRST_MATCH_TS = Time.zone.local(2026, 11, 7, 10, 12, 5).to_i
  OFFSETS = [ 0, 276, 553 ].freeze

  setup do
    @previous_token = ENV["VSMOBILE_API_TOKEN"]
    ENV["VSMOBILE_API_TOKEN"] = "test-token"
    @admin = User.create!(username: "admin_user", nickname: "管理者", password: "password123", is_admin: true)
    @admin.push_subscriptions.create!(endpoint: "https://push.example.com/1", p256dh_key: "key", auth_key: "auth")
    @event = Event.create!(name: "テスト対戦会", held_on: Date.new(2026, 11, 7), broadcast_url: "https://www.youtube.com/watch?v=test")
    @matches = OFFSETS.each_index.map { |index| create_match(played_at: Time.zone.local(2026, 11, 7, 10, 20) + (index * 5).minutes) }
  end

  teardown do
    ENV["VSMOBILE_API_TOKEN"] = @previous_token
  end

  test "統計の取り込みで、届いたデータをそのまま残し、試合の開始時刻を保存する" do
    post_stats

    assert_response :success
    assert_equal OFFSETS.map { |offset| Time.zone.at(FIRST_MATCH_TS + offset) }, @matches.map { |match| match.reload.game_started_at }
    assert_equal stats_matches.first, @matches.first.stats_payload.payload
    assert_equal [ nil, nil, nil ], @matches.map(&:video_timestamp), "1試合目の配信上の時刻がなければ、タイムスタンプは計算しない"
  end

  test "1試合目の配信上の時刻が入っていれば、統計の取り込みのあとに全試合のタイムスタンプを計算して通知する" do
    @event.update!(first_match_video_timestamp: 200)

    post_stats

    assert_equal [ 200, 476, 753 ], @matches.map { |match| match.reload.video_timestamp }
    assert_equal [ "タイムスタンプ登録完了", "テスト対戦会 の 3 試合分が登録されました" ], notified.values_at("title", "body")
  end

  test "統計の取り込みのあとに1試合目の配信上の時刻を入れると、すぐに全試合のタイムスタンプを計算する" do
    post_stats
    sign_in @admin

    patch first_match_event_timestamps_path(@event), params: { first_match_video_timestamp: "0:03:20" }

    assert_redirected_to event_timestamps_path(@event, tab: "calculate")
    assert_equal "3 試合のタイムスタンプを、試合の開始時刻から計算して保存しました。", flash[:notice]
    assert_equal [ 200, 476, 753 ], @matches.map { |match| match.reload.video_timestamp }
  end

  test "統計の取り込みの前に1試合目の配信上の時刻を入れたときは、時刻だけを保存する" do
    sign_in @admin

    patch first_match_event_timestamps_path(@event), params: { first_match_video_timestamp: "3:20" }

    assert_equal 200, @event.reload.first_match_video_timestamp
    assert_match "統計を取り込んだあとに", flash[:notice]
    assert_equal [ nil, nil, nil ], @matches.map { |match| match.reload.video_timestamp }
  end

  test "1試合目の配信上の時刻の形式が不正なら保存しない" do
    sign_in @admin

    patch first_match_event_timestamps_path(@event), params: { first_match_video_timestamp: "3分20秒" }

    assert_redirected_to event_timestamps_path(@event, tab: "calculate")
    assert_match "形式が不正です", flash[:alert]
    assert_nil @event.reload.first_match_video_timestamp
  end

  test "タイムスタンプの画面に、1試合目の配信上の時刻と各試合の開始時刻・タイムスタンプを表示する" do
    @event.update!(first_match_video_timestamp: 200)
    post_stats
    sign_in @admin

    get event_timestamps_path(@event)

    assert_response :success
    assert_select "input#first_match_video_timestamp[value=?]", "0:03:20"
    assert_select ".ed-step-title .ed-chip.done", text: "3 / 3 試合"
    assert_select ".ed-result"
    assert_select "span[title=?]", "VS.モバイルの試合の開始時刻", text: "10:12:05"
    assert_select ".ed-tr a.m-link", text: "0:03:20"
  end

  test "統計データを削除すると、試合の開始時刻と届いたデータも消す" do
    post_stats

    MatchStatisticsResetter.new(match: @matches.first.reload).reset!

    assert_nil @matches.first.reload.game_started_at
    assert_nil @matches.first.stats_payload
  end

  private

  def create_match(played_at:)
    suit = MobileSuit.first || MobileSuit.create!(name: "テスト機体", series: "テスト", cost: 3000)
    players = Array.new(4) do |index|
      number = User.count + 1
      { user: User.create!(username: "player_#{number}", nickname: "プレイヤー#{number}", password: "password123"),
        mobile_suit: suit, team_number: index < 2 ? 1 : 2, position: index + 1 }
    end
    @event.matches.create!(played_at: played_at, winning_team: 1, match_players_attributes: players)
  end

  # スクレイパー（exvs2ib-vsmobile-scraper）の出力と同じ形
  def stats_matches
    OFFSETS.each_with_index.map do |offset, index|
      {
        "match_ts" => FIRST_MATCH_TS + offset, "time" => Time.zone.at(FIRST_MATCH_TS + offset).strftime("%H:%M"),
        "game_date" => "2026/11/07(土)", "shop_name" => "テスト店",
        "team_a" => { "team_name" => "", "result" => "win", "players" => players_json(@matches[index], 1) },
        "team_b" => { "team_name" => "", "result" => "lose", "players" => players_json(@matches[index], 2) },
        "timeline_raw" => { "groups" => [], "events" => [], "game_end_cs" => 12000, "game_end_str" => "2:00.00" }
      }
    end
  end

  # 試合の 4 人を scrape.py の players の形に（統計の取り込みは 4 人の名前で試合に対応づけるため）
  def players_json(match, team_number)
    match.match_players.select { |player| player.team_number == team_number }.sort_by(&:position).map { |player| { "name" => player.user.nickname } }
  end

  def post_stats
    post "/api/events/#{@event.id}/stats", params: { matches: stats_matches, expired_users: [] }.to_json,
         headers: { "Authorization" => "Bearer test-token", "Content-Type" => "application/json" }
  end

  def notified
    job = enqueued_jobs.select { |candidate| candidate["job_class"] == "SendPushNotificationJob" }.sole
    ActiveJob::Arguments.deserialize(job["arguments"]).first.stringify_keys
  end
end
