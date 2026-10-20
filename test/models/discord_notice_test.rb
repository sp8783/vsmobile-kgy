require "test_helper"

class DiscordNoticeTest < ActiveSupport::TestCase
  setup do
    @event = Event.new(name: "第12回 対戦会", held_on: Date.new(2026, 10, 17), discord_thread_url: "https://discord.com/channels/1/2")
  end

  test "保存されていなければ、これまでと同じ文面とタイミングを使う" do
    reminder = DiscordNotice.for("reminder")

    assert reminder.new_record?
    assert reminder.enabled?
    assert_equal [ [ 7, 8 ], [ 1, 8 ] ], reminder.timing_list.map { |timing| [ timing.days_before, timing.hour ] }
    assert_equal <<~MESSAGE.chomp, reminder.message_for(@event, 1)
      @everyone
      【リマインド】
      ↓こちら、明日の開催です！！
      https://discord.com/channels/1/2
      参加したい方はフォーラムまで連絡下さい！！
    MESSAGE
    assert_includes DiscordNotice.for("preparation").message_for(@event, 1), "明日のイベントに向けて"
  end

  test "差し込み用の文字をイベントの内容に置き換える" do
    notice = DiscordNotice.new(kind: "reminder", body: "{イベント名}（{開催日}）は{いつ}！")

    assert_equal "第12回 対戦会（10/17(土)）は1週間後！", notice.message_for(@event, 7)
    assert_equal "第12回 対戦会（10/17(土)）は3日後！", notice.message_for(@event, 3)
  end

  test "値が空の差し込みを含む行は送らない" do
    notice = DiscordNotice.new(kind: "reminder", body: "リマインド\n{フォーラムURL}\nよろしく")
    @event.discord_thread_url = nil

    assert_equal "リマインド\nよろしく", notice.message_for(@event, 1)
  end

  test "フォームから来た文字列のタイミングを整数にそろえる" do
    notice = DiscordNotice.new(kind: "reminder", body: "本文", timings: [ { "days_before" => "3", "hour" => "21" } ])

    assert_equal [ { "days_before" => 3, "hour" => 21 } ], notice.timings
    assert notice.valid?
  end

  test "タイミングの日数・時刻は範囲内にする" do
    notice = DiscordNotice.new(kind: "reminder", body: "本文", timings: [ { days_before: 15, hour: 8 } ])

    assert_not notice.valid?
    assert_includes notice.errors.full_messages, "送るタイミングの日数・時刻が正しくありません"
  end

  test "同じ日数のタイミングは 2 つ作れない" do
    notice = DiscordNotice.new(kind: "reminder", body: "本文", timings: [ { days_before: 1, hour: 8 }, { days_before: 1, hour: 20 } ])

    assert_not notice.valid?
  end

  test "リマインドはタイミングを 0 個にでき、事前準備のお願いは 1 つだけにする" do
    assert DiscordNotice.new(kind: "reminder", body: "本文", timings: []).valid?
    assert_not DiscordNotice.new(kind: "preparation", body: "本文", timings: []).valid?
    assert_not DiscordNotice.new(kind: "preparation", body: "本文", timings: [ { days_before: 1, hour: 8 }, { days_before: 2, hour: 8 } ]).valid?
  end

  test "登録の連絡はタイミングを持たず、登録したものと対戦履歴のリンクを差し込む" do
    notice = DiscordNotice.for("data_registered")

    assert_not notice.scheduled?
    assert notice.to_thread?
    assert_equal "event_forum", notice.purpose
    assert_equal DiscordNotice::REGISTRATION_PLACEHOLDERS, notice.placeholders
    assert_equal "第12回 対戦会 の対戦履歴に、次のデータを登録しました。\n- 各試合の統計\n- 配信アーカイブのタイムスタンプ\n\n本イベントの対戦履歴: http://example.com/events/1",
                 notice.registration_message_for(@event, %w[stats timestamps], event_url: "http://example.com/events/1")
    assert_equal "第12回 対戦会 の対戦履歴に、次のデータを登録しました。\n- 各試合の統計\n\n本イベントの対戦履歴: http://example.com/events/1",
                 notice.registration_message_for(@event, %w[stats], event_url: "http://example.com/events/1")
    assert_not DiscordNotice.new(kind: "data_registered", body: "本文", timings: [ { days_before: 1, hour: 8 } ]).valid?
  end
end
