require "test_helper"

class EventReminderJobTest < ActiveSupport::TestCase
  THREAD_URL = "https://discord.com/channels/731348521269329971/1490000000000000001".freeze

  setup do
    @posts = []
    @now = Time.zone.local(2026, 10, 10, 8, 0)
  end

  test "前日は、フォーラムの記事に事前準備のお願いを投稿してから、リマインドを送る" do
    Event.create!(name: "対戦会", held_on: @now.to_date + 1, discord_thread_url: THREAD_URL)

    perform

    assert_equal [ [ "event_forum", "1490000000000000001" ], [ "reminder", nil ] ], @posts.map { |post| post.values_at(:purpose, :thread_id) }
    assert_includes @posts.first[:message], "【事前準備のお願い】"
    assert_includes @posts.last[:message], THREAD_URL
  end

  test "スレッド URL がないイベントは、事前準備のお願いを投稿しない" do
    Event.create!(name: "対戦会", held_on: @now.to_date + 1)

    perform

    assert_equal [ "reminder" ], @posts.map { |post| post[:purpose] }
  end

  test "1 週間前は、リマインドだけを送る" do
    Event.create!(name: "対戦会", held_on: @now.to_date + 7, discord_thread_url: THREAD_URL)

    perform

    assert_equal [ "reminder" ], @posts.map { |post| post[:purpose] }
    assert_includes @posts.first[:message], "1週間後"
  end

  test "設定した時刻でなければ送らない" do
    Event.create!(name: "対戦会", held_on: @now.to_date + 1, discord_thread_url: THREAD_URL)

    perform(now: @now.change(hour: 9))

    assert_empty @posts
  end

  test "設定したタイミングと時刻で送る" do
    DiscordNotice.create!(kind: "reminder", body: "{いつ}の開催です", timings: [ { days_before: 3, hour: 21 } ])
    Event.create!(name: "対戦会", held_on: @now.to_date + 3)

    perform(now: @now.change(hour: 21))

    assert_equal [ "3日後の開催です" ], @posts.map { |post| post[:message] }
  end

  test "送らない設定の投稿は送らない" do
    DiscordNotice.create!(kind: "reminder", enabled: false, **DiscordNotice::DEFAULTS["reminder"])
    Event.create!(name: "対戦会", held_on: @now.to_date + 7)

    perform

    assert_empty @posts
  end

  test "一度送った投稿は、時刻の設定を変えても二重に送らない" do
    Event.create!(name: "対戦会", held_on: @now.to_date + 7)
    perform
    DiscordNotice.create!(kind: "reminder", body: "本文", timings: [ { days_before: 7, hour: 20 } ])

    perform(now: @now.change(hour: 20))

    assert_equal 1, @posts.size
  end

  test "投稿に失敗したら記録しない" do
    Event.create!(name: "対戦会", held_on: @now.to_date + 7)

    perform(result: false)

    assert DiscordNoticeDelivery.none?
  end

  private

  def perform(now: @now, result: true)
    EventReminderJob.new.perform(now: now, poster: ->(**post) { @posts << post; result })
  end
end
