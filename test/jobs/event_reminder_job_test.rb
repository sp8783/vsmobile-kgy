require "test_helper"

class EventReminderJobTest < ActiveSupport::TestCase
  THREAD_URL = "https://discord.com/channels/731348521269329971/1490000000000000001".freeze

  setup do
    @posts = []
  end

  test "前日は、フォーラムの記事に事前準備のお願いを投稿してから、リマインドを送る" do
    Event.create!(name: "対戦会", held_on: Date.current + 1, discord_thread_url: THREAD_URL)

    perform

    assert_equal [ [ :event_forum, "1490000000000000001" ], [ :reminder, nil ] ], @posts.map { |post| post.values_at(:purpose, :thread_id) }
    assert_includes @posts.first[:message], "【事前準備のお願い】"
    assert_includes @posts.last[:message], THREAD_URL
  end

  test "スレッド URL がないイベントは、事前準備のお願いを投稿しない" do
    Event.create!(name: "対戦会", held_on: Date.current + 1)

    perform

    assert_equal [ :reminder ], @posts.map { |post| post[:purpose] }
  end

  test "1 週間前は、リマインドだけを送る" do
    Event.create!(name: "対戦会", held_on: Date.current + 7, discord_thread_url: THREAD_URL)

    perform

    assert_equal [ :reminder ], @posts.map { |post| post[:purpose] }
    assert_includes @posts.first[:message], "1週間後"
  end

  private

  def perform
    EventReminderJob.new.perform(poster: ->(**post) { @posts << post; true })
  end
end
