require "test_helper"

class RotationShowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include RotationTestHelper

  setup do
    @players = build_players
    @rotation = build_rotation(@players)
    @admin = User.create!(username: "admin_user", nickname: "管理者", password: "password123", is_admin: true)
    sign_in @admin
  end

  test "現在の試合は「試合をスキップする」「次の試合へ進む」と結果未入力の確認ダイアログを表示する" do
    get rotation_path(@rotation)

    assert_response :success
    assert_select "#match-record-container .r-rf-h", text: "結果を入力"
    assert_select "button", text: "試合をスキップする"
    assert_select "button[data-defer='true']", text: "次の試合へ進む"
    assert_select "[data-rotation-record-target='deferModal'][hidden]" do
      assert_select "p", text: "この試合は対戦済みとして扱われます。"
      assert_select "p.text-xs", text: "※ 結果はあとから入力できます。"
      assert_select ".r-missing-h", text: "未入力の項目"
      assert_select "ul[data-rotation-record-target='missing']"
    end
    assert_select ".r-status.st-un", text: "予定"
  end

  test "結果が未入力の試合はチップと一覧から開け、その試合のプレイヤーでフォームを表示する" do
    manager.next_match!(expected_index: 0)

    get rotation_path(@rotation)
    assert_select ".r-pendchip", text: "第1試合"
    assert_select ".r-status.st-pend", text: "未入力"
    assert_select "a", text: "入力"

    get rotation_path(@rotation, target: 0)
    assert_select "#match-record-container .r-rf-h", text: "第1試合の結果を入力"
    assert_select ".r-rf-note", text: "現在の試合（第2試合）はそのままです"
    assert_select "form[action='#{record_pending_match_rotation_path(@rotation)}']"
    assert_select "label[for='team2_player2_suit']", text: "Dさん"
    assert_select "select[name='team2_player2_suit'][data-player-name='Dさん']"
    assert_select "button", text: "保存する"
    assert_select "button", text: "次の試合へ進む", count: 0
    assert_select "a", text: "現在の試合に戻る", count: 2
    assert_select "tr.edittr .r-edit-tag", text: "入力中"
  end

  test "結果が入力済みの試合は編集フォームで表示する" do
    manager.record_current_match!(winning_team: 1, suit_ids: suit_ids, expected_index: 0)

    get rotation_path(@rotation, target: 0)

    assert_select "#match-record-container .r-rf-h", text: "第1試合の結果を編集"
    assert_select "form[action='#{update_match_record_rotation_path(@rotation)}']"
    assert_select "input[name='winning_team'][value='1'][checked]"
  end

  test "予定の試合を target に指定しても現在の試合のフォームを表示する" do
    get rotation_path(@rotation, target: 5)

    assert_select "#match-record-container .r-rf-h", text: "結果を入力"
  end

  test "最後の試合は結果未入力のまま進めないので「保存する」を表示する" do
    @rotation.update!(current_match_index: 7)

    get rotation_path(@rotation)

    assert_select "button[data-defer='false']", text: "保存する"
    assert_select "button", text: "試合をスキップする", count: 0
    assert_select "[data-rotation-record-target='deferModal']", count: 0
  end

  test "スキップした試合には「この試合を始める」を表示する" do
    manager.skip_match!(expected_index: 0)

    get rotation_path(@rotation)

    assert_select "button", text: "この試合を始める"
    assert_select "a", text: "現在の試合に戻る", count: 0
  end

  test "結果を入力せずに次へ進むとお知らせを表示する" do
    post next_match_rotation_path(@rotation), params: { match_index: 0 }

    assert_redirected_to rotation_path(@rotation)
    assert_equal "第1試合を結果未入力のまま、次の試合へ進みました", flash[:notice]
  end

  private

  def manager
    RotationWorkflowManager.new(rotation: @rotation.reload)
  end
end
