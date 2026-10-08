require "test_helper"

class RotationWorkflowManagerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include RotationTestHelper

  setup do
    @players = build_players
    @rotation = build_rotation(@players)
  end

  test "結果を入力せずに次へ進むと、現在の試合は未入力になる" do
    result = manager.next_match!(expected_index: 0)

    assert result.success?
    assert_equal 1, @rotation.reload.current_match_index
    assert_equal %i[pending current upcoming upcoming upcoming upcoming upcoming upcoming], statuses(@rotation)
  end

  test "スキップすると、現在の試合はスキップになる" do
    result = manager.skip_match!(expected_index: 0)

    assert result.success?
    assert_equal %i[skipped current upcoming upcoming upcoming upcoming upcoming upcoming], statuses(@rotation)
  end

  test "画面表示時から進行状況が変わっていたら進めない" do
    manager.next_match!(expected_index: 0)

    result = manager.next_match!(expected_index: 0)

    assert_not result.success?
    assert_equal 1, @rotation.reload.current_match_index
  end

  test "次の試合がなければ結果を入力せずに進めない" do
    @rotation.update!(current_match_index: 7)

    assert_not manager.next_match!(expected_index: 7).success?
    assert_not manager.skip_match!(expected_index: 7).success?
  end

  test "最後まで入力するとスキップした試合へ戻り、未入力の試合には戻らない" do
    manager.skip_match!(expected_index: 0)
    manager.next_match!(expected_index: 1)
    (2..7).each { |index| record_current(index) }

    @rotation.reload
    assert_equal 0, @rotation.current_match_index
    first = @rotation.rotation_matches.find_by(match_index: 0)
    assert_not first.skipped?, "戻った試合はスキップを解除する"
    assert_equal :pending, @rotation.rotation_matches.find_by(match_index: 1).progress_status(0)
  end

  test "未入力の試合は現在の試合を動かさずに入力でき、全試合がそろうと完了する" do
    manager.next_match!(expected_index: 0)
    (1..7).each { |index| record_current(index) }
    pending = @rotation.rotation_matches.find_by(match_index: 0)

    assert_not @rotation.reload.rotation_matches.where(match_id: nil).none?
    current_before = @rotation.current_match_index

    result = manager.record_pending_match!(match_index: 0, winning_team: 2, suit_ids: suit_ids)

    assert result.success?
    assert result.completed
    @rotation.reload
    assert_equal current_before, @rotation.current_match_index
    assert_not @rotation.is_active
    assert_equal pending.started_at.to_i, pending.reload.match.played_at.to_i, "対戦日時は試合の開始時刻"
  end

  test "未入力でない試合は未入力の試合として保存できない" do
    result = manager.record_pending_match!(match_index: 3, winning_team: 1, suit_ids: suit_ids)

    assert_not result.success?
    assert_nil @rotation.rotation_matches.find_by(match_index: 3).match_id
  end

  test "スキップした試合に戻ると、それまでの現在の試合は予定に戻る" do
    manager.skip_match!(expected_index: 0)

    result = manager.go_to_match!(match_index: 0)

    assert result.success?
    assert_equal %i[current upcoming upcoming upcoming upcoming upcoming upcoming upcoming], statuses(@rotation)
  end

  test "スキップした試合以外には戻れない" do
    manager.next_match!(expected_index: 0)

    assert_not manager.go_to_match!(match_index: 0).success?
    assert_equal 1, @rotation.reload.current_match_index
  end

  test "通知は未入力・スキップの試合を除いた順番で数える" do
    manager.skip_match!(expected_index: 0)
    manager.next_match!(expected_index: 1)
    manager.go_to_match!(match_index: 0)
    # 並び: 第1試合（現在）→ 第3試合 → 第4試合（第2試合は未入力なので除く）
    @players.each_value { |user| user.push_subscriptions.create!(endpoint: "https://push.example/#{user.id}", p256dh_key: "k", auth_key: "a") }
    clear_enqueued_jobs

    manager.send(:notify_upcoming_players, @rotation.reload)

    titles = enqueued_jobs.to_h { |job| [ job[:args].first["user_id"], job[:args].first["title"] ] }
    # Eさんの次の出番は第3試合。未入力の第2試合を除くと「あと1試合」
    assert_equal "あと1試合です【現在：第1試合】", titles[@players["E"].id]
  end

  test "試合を削除すると未入力に戻り、現在の試合は動かない" do
    record_current(0)
    match = @rotation.rotation_matches.find_by(match_index: 0).match

    MatchDeletionWorkflow.new(matches: match).call

    assert_equal 1, @rotation.reload.current_match_index
    assert_equal :pending, @rotation.rotation_matches.find_by(match_index: 0).progress_status(1)
  end

  private

  def manager
    RotationWorkflowManager.new(rotation: @rotation.reload)
  end

  def record_current(index)
    result = manager.record_current_match!(winning_team: 1, suit_ids: suit_ids, expected_index: index)
    assert result.success?, result.error_message
  end
end
