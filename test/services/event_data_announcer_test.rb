require "test_helper"

# 統計・タイムスタンプが全試合そろったら、イベントの Discord フォーラムの記事に知らせる
class EventDataAnnouncerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  THREAD_URL = "https://discord.com/channels/731348521269329971/1490000000000000001".freeze

  setup do
    @posts = []
    @event = Event.create!(name: "第6回 対戦会", held_on: Date.new(2026, 11, 7), discord_thread_url: THREAD_URL)
    @matches = Array.new(2) { |index| create_match(played_at: Time.zone.local(2026, 11, 7, 10, 20) + index.minutes) }
  end

  test "統計とタイムスタンプが全試合そろっていれば、1 回でまとめて知らせて記録する" do
    register_stats(@matches)
    register_timestamps(@matches)

    result = announcer.announce!

    assert result.posted?
    assert_equal %w[stats timestamps], result.kinds
    assert_equal [ [ "event_forum", "1490000000000000001" ] ], @posts.map { |post| post.values_at(:purpose, :thread_id) }
    assert_equal "第6回 対戦会 の対戦履歴に、次のデータを登録しました。\n- 各試合の統計\n- 配信アーカイブのタイムスタンプ\n\n本イベントの対戦履歴: http://example.com/events/#{@event.id}", @posts.first[:message]
    @event.reload
    assert_not_nil @event.stats_announced_at
    assert_equal @event.stats_announced_at, @event.timestamps_announced_at
  end

  test "統計だけそろっていれば統計だけ知らせ、あとでタイムスタンプがそろったらタイムスタンプだけ知らせる" do
    register_stats(@matches)
    announcer.announce!
    register_timestamps(@matches)

    result = announcer.announce!

    assert_equal %w[timestamps], result.kinds
    assert_equal [ "第6回 対戦会 の対戦履歴に、次のデータを登録しました。\n- 各試合の統計\n\n本イベントの対戦履歴: http://example.com/events/#{@event.id}",
                   "第6回 対戦会 の対戦履歴に、次のデータを登録しました。\n- 配信アーカイブのタイムスタンプ\n\n本イベントの対戦履歴: http://example.com/events/#{@event.id}" ],
                 @posts.map { |post| post[:message] }
  end

  test "一部の試合だけでは知らせない" do
    register_stats(@matches.first(1))

    result = announcer.announce!

    assert_not result.posted?
    assert_equal "Discord に知らせるものがありません。", result.error_message
    assert_empty @posts
    assert_equal [], announcer.pending_kinds
  end

  test "一度知らせたものは、直しても二重に知らせない" do
    register_stats(@matches)
    announcer.announce!
    @matches.first.match_timeline.update!(timeline_raw: { "groups" => [], "events" => [ { "t" => 1 } ] })

    result = announcer.announce!

    assert_not result.posted?
    assert_equal 1, @posts.size
  end

  test "スレッド URL がなければ知らせない" do
    @event.update!(discord_thread_url: nil)
    register_stats(@matches)

    result = announcer.announce!

    assert_not result.posted?
    assert_match "Discord フォーラムスレッド URL が入っていません", result.error_message
    assert_not announcer.can_post?
    assert_equal %w[stats], announcer.pending_kinds, "そろっているものは予備のボタンで知らせられる"
  end

  test "投稿に失敗したら記録せず、次に知らせられるようにしておく" do
    register_stats(@matches)

    result = announcer(result: false).announce!

    assert_not result.posted?
    assert_match "Discord への投稿に失敗しました", result.error_message
    assert_nil @event.reload.stats_announced_at
    assert_equal %w[stats], announcer.pending_kinds
  end

  test "文面は管理画面の「登録の連絡」の設定を使う" do
    DiscordNotice.create!(kind: "data_registered", body: "{イベント名}: {登録したもの}を入れました\n{対戦履歴URL}", timings: [])
    register_stats(@matches)

    announcer.announce!

    assert_equal "第6回 対戦会: 各試合の統計を入れました\nhttp://example.com/events/#{@event.id}", @posts.first[:message]
  end

  test "「登録の連絡」が送らない設定なら知らせない" do
    DiscordNotice.create!(kind: "data_registered", enabled: false, **DiscordNotice::DEFAULTS["data_registered"])
    register_stats(@matches)

    result = announcer.announce!

    assert_not result.posted?
    assert_match "送らない設定です", result.error_message
    assert_empty @posts
    assert_not announcer.can_post?
    assert_no_enqueued_jobs(only: AnnounceEventDataJob) { EventDataAnnouncer.announce_later(@event) }
  end

  test "announce_later は、知らせるものがあるときだけジョブを積む" do
    assert_no_enqueued_jobs(only: AnnounceEventDataJob) { EventDataAnnouncer.announce_later(@event) }

    register_stats(@matches)
    assert_enqueued_with(job: AnnounceEventDataJob, args: [ @event.id ]) { EventDataAnnouncer.announce_later(@event) }

    @event.update!(discord_thread_url: nil)
    assert_no_enqueued_jobs(only: AnnounceEventDataJob) { EventDataAnnouncer.announce_later(@event) }
  end

  private

  def announcer(result: true)
    EventDataAnnouncer.new(event: @event, poster: ->(**post) { @posts << post; result })
  end

  def register_stats(matches)
    matches.each { |match| match.create_match_timeline!(timeline_raw: { "groups" => [], "events" => [] }) }
  end

  def register_timestamps(matches)
    matches.each_with_index { |match, index| match.update!(video_timestamp: 200 + index * 300) }
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
