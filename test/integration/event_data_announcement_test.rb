require "test_helper"

# 統計・タイムスタンプの登録のあとに Discord のフォーラムの記事へ知らせる流れと、イベント詳細の連絡の状況・予備のボタン
class EventDataAnnouncementTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include Devise::Test::IntegrationHelpers

  THREAD_URL = "https://discord.com/channels/731348521269329971/1490000000000000001".freeze
  FIRST_MATCH_TS = Time.zone.local(2026, 11, 7, 10, 12, 5).to_i
  OFFSETS = [ 0, 276 ].freeze

  setup do
    @previous_token = ENV["VSMOBILE_API_TOKEN"]
    ENV["VSMOBILE_API_TOKEN"] = "test-token"
    @admin = User.create!(username: "admin_user", nickname: "管理者", password: "password123", is_admin: true)
    @event = Event.create!(name: "テスト対戦会", held_on: Date.new(2026, 11, 7), broadcast_url: "https://www.youtube.com/watch?v=test", discord_thread_url: THREAD_URL)
    @matches = OFFSETS.each_index.map { |index| create_match(played_at: Time.zone.local(2026, 11, 7, 10, 20) + (index * 5).minutes) }
    sign_in @admin
  end

  teardown do
    ENV["VSMOBILE_API_TOKEN"] = @previous_token
  end

  test "統計の取り込みで統計とタイムスタンプがそろったら、知らせるジョブを 1 つ積む" do
    @event.update!(first_match_video_timestamp: 200)

    assert_enqueued_with(job: AnnounceEventDataJob, args: [ @event.id ]) { post_stats }
    assert_equal 1, enqueued_jobs.count { |job| job["job_class"] == "AnnounceEventDataJob" }
  end

  test "スレッド URL がなければ、そろってもジョブを積まない" do
    @event.update!(discord_thread_url: nil, first_match_video_timestamp: 200)

    assert_no_enqueued_jobs(only: AnnounceEventDataJob) { post_stats }
  end

  test "動画解析のタイムスタンプの登録でそろったら、知らせるジョブを積む" do
    assert_enqueued_with(job: AnnounceEventDataJob, args: [ @event.id ]) do
      post "/api/events/#{@event.id}/timestamps", params: { timestamps: "0:03:20\n0:08:00" }.to_json, headers: api_headers
    end
  end

  test "手で入力したタイムスタンプで全試合そろったら、知らせるジョブを積む" do
    assert_enqueued_with(job: AnnounceEventDataJob, args: [ @event.id ]) do
      patch event_timestamps_path(@event), params: { timestamps: "0:03:20\n0:08:00" }
    end
  end

  test "試合ごとの統計の入力で全試合そろったら、知らせるジョブを積む" do
    @matches.first.create_match_timeline!(timeline_raw: { "groups" => [], "events" => [] })

    assert_enqueued_with(job: AnnounceEventDataJob, args: [ @event.id ]) do
      patch match_stats_path(@matches.last), params: { match_timeline: { timeline_raw_text: '{"groups":[],"events":[]}' } }
    end
  end

  test "ジョブが Discord に知らせて記録する" do
    @matches.each { |match| match.create_match_timeline!(timeline_raw: { "groups" => [], "events" => [] }) }

    stub_discord_post(true) { AnnounceEventDataJob.perform_now(@event.id) }

    assert_not_nil @event.reload.stats_announced_at
    assert_nil @event.timestamps_announced_at
  end

  test "イベント詳細に連絡の状況を出す。そろっていなければボタンは出さない" do
    get event_path(@event)

    assert_response :success
    assert_select ".ed-announce", text: /統計・タイムスタンプが全試合そろうと、自動で知らせます/
    assert_select ".ed-announce form", 0
  end

  test "スレッド URL がなければ、入れるように案内する" do
    @event.update!(discord_thread_url: nil)

    get event_path(@event)

    assert_select ".ed-announce", text: /Discord フォーラムスレッド URL を入れると/
  end

  test "知らせたものは時刻つきで出す" do
    @event.update!(stats_announced_at: Time.zone.local(2026, 11, 7, 18, 32))

    get event_path(@event)

    assert_select ".ed-announce", text: /知らせました: 各試合の統計（11\/7 18:32）/
  end

  test "そろっているのに知らせていなければボタンを出し、押すと知らせて記録する" do
    @matches.each { |match| match.create_match_timeline!(timeline_raw: { "groups" => [], "events" => [] }) }

    get event_path(@event)
    assert_select ".ed-announce", text: /各試合の統計がそろっていますが、まだ知らせていません/
    assert_select ".ed-announce form[action=?]", announce_data_to_discord_event_path(@event)

    stub_discord_post(true) { post announce_data_to_discord_event_path(@event) }

    assert_redirected_to event_path(@event)
    assert_equal "Discord のフォーラムの記事に、各試合の統計の登録を知らせました。", flash[:notice]
    assert_not_nil @event.reload.stats_announced_at
  end

  test "投稿に失敗したら知らせて、記録しない" do
    @matches.each { |match| match.create_match_timeline!(timeline_raw: { "groups" => [], "events" => [] }) }

    post announce_data_to_discord_event_path(@event)

    assert_redirected_to event_path(@event)
    assert_match "Discord への投稿に失敗しました", flash[:alert]
    assert_nil @event.reload.stats_announced_at
  end

  private

  # Discord への投稿を差し替える（minitest/mock は入っていない）
  def stub_discord_post(result)
    original = DiscordWebhookService.method(:post)
    DiscordWebhookService.define_singleton_method(:post) { |**| result }
    yield
  ensure
    DiscordWebhookService.define_singleton_method(:post, original)
  end

  def post_stats
    matches = OFFSETS.each_with_index.map do |offset, index|
      { "match_ts" => FIRST_MATCH_TS + offset, "team_a" => { "players" => players_json(@matches[index], 1) }, "team_b" => { "players" => players_json(@matches[index], 2) },
        "timeline_raw" => { "groups" => [], "events" => [], "game_end_cs" => 12000, "game_end_str" => "2:00.00" } }
    end
    post "/api/events/#{@event.id}/stats", params: { matches: matches, expired_users: [] }.to_json, headers: api_headers
    assert_response :success
  end

  # 試合の 4 人を scrape.py の players の形に（統計の取り込みは 4 人の名前で試合に対応づけるため）
  def players_json(match, team_number)
    match.match_players.select { |player| player.team_number == team_number }.sort_by(&:position).map { |player| { "name" => player.user.nickname } }
  end

  def api_headers
    { "Authorization" => "Bearer test-token", "Content-Type" => "application/json" }
  end

  def create_match(played_at:)
    suit = MobileSuit.first || MobileSuit.create!(name: "テスト機体", series: "テスト", cost: 3000)
    players = Array.new(4) do |index|
      number = User.count + 1
      { user: User.create!(username: "player_#{number}", nickname: "プレイヤー#{number}", password: "password123"),
        mobile_suit: suit, team_number: index < 2 ? 1 : 2, position: index + 1 }
    end
    @event.matches.create!(played_at: played_at, winning_team: 1, match_players_attributes: players)
  end
end
