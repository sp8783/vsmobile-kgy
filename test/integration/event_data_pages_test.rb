require "test_helper"

class EventDataPagesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = User.create!(username: "admin_user", nickname: "管理者", password: "password123", is_admin: true)
    @event = Event.create!(name: "テスト対戦会", held_on: Date.new(2026, 11, 7), broadcast_url: "https://www.youtube.com/watch?v=test")
    @matches = Array.new(2) { |index| create_match(played_at: Time.zone.local(2026, 11, 7, 10, 20) + index.minutes) }
    @matches.first.update!(video_timestamp: 200)
    @matches.first.create_match_timeline!(timeline_raw: { "groups" => [], "events" => [] })
    sign_in @admin
  end

  test "イベント詳細に、タイムスタンプと統計の登録状況のカードを出す" do
    get event_path(@event)

    assert_response :success
    assert_select "a.ed-card[href=?]", event_timestamps_path(@event), text: /配信アーカイブのタイムスタンプ.*1 \/ 2/m
    assert_select "a.ed-card[href=?]", event_stats_path(@event), text: /各試合の統計.*1 \/ 2/m
  end

  test "配信 URL がないイベントでは、タイムスタンプのカードを出さない" do
    @event.update!(broadcast_url: nil)

    get event_path(@event)

    assert_select "a.ed-card", 1
    assert_select "a.ed-card[href=?]", event_stats_path(@event)
  end

  test "管理者でなければ、カードを出さず、登録の画面も開けない" do
    sign_in User.create!(username: "player", nickname: "プレイヤー", password: "password123")

    get event_path(@event)
    assert_select "a.ed-card", 0

    get event_timestamps_path(@event)
    assert_redirected_to root_path
    get event_stats_path(@event)
    assert_redirected_to root_path
  end

  test "タイムスタンプの画面は、選んだ登録のしかただけを表示する" do
    get event_timestamps_path(@event)
    assert_select ".st-tab.on", text: "試合の開始時刻から計算（おすすめ）"
    assert_select "input#first_match_video_timestamp"
    assert_select "textarea#timestamps", 0

    get event_timestamps_path(@event, tab: "manual")
    assert_select ".st-tab.on", text: "手で入力"
    assert_select "textarea#timestamps", text: "0:03:20\n"
    assert_select "input#first_match_video_timestamp", 0

    get event_timestamps_path(@event, tab: "analysis")
    assert_select "form[action=?] button", analysis_event_timestamps_path(@event), text: "解析を始める"
  end

  test "タイムスタンプの画面に、動画解析の時刻と 25 秒以上の違いを出す" do
    @event.update!(first_match_video_timestamp: 200)
    @matches.each_with_index { |match, index| match.update!(game_started_at: Time.zone.local(2026, 11, 7, 10, 12, 5) + (index * 300), video_timestamp: 200 + index * 300, analysis_video_timestamp: 200 + index * 330) }

    get event_timestamps_path(@event, tab: "analysis")

    assert_response :success
    assert_select ".ed-result", text: /2 試合を比べました。差の中央値 \+15 秒・最大 \+30 秒。25 秒以上の違い: 第2試合（\+30 秒）/
    assert_select ".ed-tr .ed-chip.warn", text: "+30 秒", count: 1
    assert_select ".ed-tr", text: /0:08:50/
  end

  test "手で入力したタイムスタンプを保存すると、手で入力のタブに戻る" do
    patch event_timestamps_path(@event), params: { timestamps: "0:03:20\n0:08:00" }

    assert_redirected_to event_timestamps_path(@event, tab: "manual")
    assert_equal [ 200, 480 ], @matches.map { |match| match.reload.video_timestamp }
  end

  test "手で入力したタイムスタンプの行数が合わなければ、理由を出して入力を残す" do
    patch event_timestamps_path(@event), params: { timestamps: "0:03:20" }

    assert_response :unprocessable_entity
    assert_select ".st-tab.on", text: "手で入力"
    assert_select "textarea#timestamps", text: "0:03:20"
    assert_match "行数（1）と試合数（2）が一致しません", response.body
  end

  test "解析を始められないときは、理由を出して動画を解析のタブに戻る" do
    with_env("GITHUB_REPO" => nil) do
      post analysis_event_timestamps_path(@event)
    end

    assert_redirected_to event_timestamps_path(@event, tab: "analysis")
    assert_match "GitHub Actions の設定が不完全です", flash[:alert]
  end

  test "統計の画面に、試合ごとの取り込みの状態と入力画面へのリンクを出す" do
    get event_stats_path(@event, tab: "per_match")

    assert_response :success
    assert_select ".st-tab.on", text: "試合ごとに入力"
    assert_select ".ed-tr .ed-chip.done", text: "取り込み済み", count: 1
    assert_select "a[href=?]", edit_match_stats_path(@matches.first), text: "直す"
    assert_select "a[href=?]", edit_match_stats_path(@matches.last), text: "入力する"
  end

  test "統計の取得を始められないときは、理由を出して一括取得のタブに戻る" do
    with_env("SCRAPER_GITHUB_REPO" => nil) do
      post scraping_event_stats_path(@event)
    end

    assert_redirected_to event_stats_path(@event, tab: "bulk")
    assert_match "スクレイパーの設定が不完全です", flash[:alert]
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

  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
