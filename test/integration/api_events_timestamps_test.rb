require "test_helper"

# 動画解析（exvs2ib-replay-parser）から届いたタイムスタンプの登録と、試合の開始時刻から計算したタイムスタンプとの照合
class ApiEventsTimestampsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  FIRST_MATCH_TS = Time.zone.local(2026, 11, 7, 10, 12, 5).to_i
  OFFSETS = [ 0, 276, 553 ].freeze

  setup do
    @previous_token = ENV["VSMOBILE_API_TOKEN"]
    ENV["VSMOBILE_API_TOKEN"] = "test-token"
    admin = User.create!(username: "admin_user", nickname: "管理者", password: "password123", is_admin: true)
    admin.push_subscriptions.create!(endpoint: "https://push.example.com/1", p256dh_key: "key", auth_key: "auth")
    @event = Event.create!(name: "テスト対戦会", held_on: Date.new(2026, 11, 7), broadcast_url: "https://www.youtube.com/watch?v=test")
    @matches = OFFSETS.each_index.map { |index| create_match(played_at: Time.zone.local(2026, 11, 7, 10, 20) + (index * 5).minutes) }
  end

  teardown do
    ENV["VSMOBILE_API_TOKEN"] = @previous_token
  end

  test "試合の開始時刻がなければ、動画解析のタイムスタンプをそのまま登録して通知する" do
    post_timestamps("0:03:20\n0:08:00\n0:12:30")

    assert_response :success
    assert_equal [ 200, 480, 750 ], @matches.map { |match| match.reload.video_timestamp }
    assert_equal [ 200, 480, 750 ], @matches.map(&:analysis_video_timestamp)
    assert_equal [ "タイムスタンプ登録完了" ], notified_titles
  end

  test "計算したタイムスタンプがあれば上書きせず、動画解析の結果と比べて通知する" do
    import_game_start_times(first_match_video_timestamp: 200)

    post_timestamps("0:03:20\n0:08:00\n0:13:03")

    assert_response :success
    assert_equal [ 200, 476, 753 ], @matches.map { |match| match.reload.video_timestamp }, "計算したタイムスタンプのまま"
    assert_equal [ 200, 480, 783 ], @matches.map(&(:analysis_video_timestamp))
    assert_equal [ "タイムスタンプ照合結果" ], notified_titles
    assert_equal "テスト対戦会: 3 試合を比べました。差の中央値 +4 秒・最大 +30 秒。25 秒以上の違い: 第3試合（+30 秒）", notified.last["body"]
    assert_equal "3 試合を比べました。差の中央値 +4 秒・最大 +30 秒。25 秒以上の違い: 第3試合（+30 秒）", response.parsed_body["comparison"]
  end

  test "違いがなければ、なしと通知する" do
    import_game_start_times(first_match_video_timestamp: 200)

    post_timestamps("0:03:22\n0:07:54\n0:12:35")

    assert_equal "テスト対戦会: 3 試合を比べました。差の中央値 +2 秒・最大 +2 秒。25 秒以上の違い: なし", notified.last["body"]
  end

  test "1試合目の配信上の時刻がなければ、動画解析の1試合目を使って計算し、登録と照合を通知する" do
    import_game_start_times

    post_timestamps("0:03:20\n0:08:00\n0:12:30")

    assert_equal 200, @event.reload.first_match_video_timestamp
    assert_equal [ 200, 476, 753 ], @matches.map { |match| match.reload.video_timestamp }
    assert_equal [ "タイムスタンプ照合結果" ], notified_titles
  end

  test "動画解析の結果が先に届いていれば、統計の取り込みで計算したあとに比べて通知する" do
    post_timestamps("0:03:20\n0:08:00\n0:13:03")

    @event.update!(first_match_video_timestamp: 200)
    import_game_start_times(first_match_video_timestamp: 200, keep_notifications: true)

    assert_equal [ 200, 476, 753 ], @matches.map { |match| match.reload.video_timestamp }
    assert_equal [ "タイムスタンプ登録完了", "タイムスタンプ登録完了", "タイムスタンプ照合結果" ], notified_titles
    assert_match "第3試合（+30 秒）", notified.last["body"]
  end

  test "行数が試合数と合わなければ、登録せずに失敗を通知する" do
    post_timestamps("0:03:20\n0:08:00")

    assert_response :unprocessable_entity
    assert_equal [ nil, nil, nil ], @matches.map { |match| match.reload.analysis_video_timestamp }
    assert_equal [ "タイムスタンプ登録失敗" ], notified_titles
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

  # 統計の取り込みで、各試合の開始時刻（match_ts）が入った状態にする
  def import_game_start_times(first_match_video_timestamp: nil, keep_notifications: false)
    @event.update!(first_match_video_timestamp: first_match_video_timestamp)
    matches = OFFSETS.map do |offset|
      { "match_ts" => FIRST_MATCH_TS + offset, "team_a" => { "players" => [] }, "team_b" => { "players" => [] },
        "timeline_raw" => { "groups" => [], "events" => [], "game_end_cs" => 12000, "game_end_str" => "2:00.00" } }
    end
    post "/api/events/#{@event.id}/stats", params: { matches: matches, expired_users: [] }.to_json, headers: headers
    assert_response :success
    clear_enqueued_jobs unless keep_notifications
  end

  def post_timestamps(text)
    post "/api/events/#{@event.id}/timestamps", params: { timestamps: text }.to_json, headers: headers
  end

  def headers
    { "Authorization" => "Bearer test-token", "Content-Type" => "application/json" }
  end

  def notified
    enqueued_jobs.select { |candidate| candidate["job_class"] == "SendPushNotificationJob" }
                 .map { |job| ActiveJob::Arguments.deserialize(job["arguments"]).first.stringify_keys }
  end

  def notified_titles
    notified.map { |notification| notification["title"] }
  end
end
