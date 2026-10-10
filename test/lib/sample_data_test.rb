require "test_helper"

class SampleDataTest < ActiveSupport::TestCase
  # 過去のイベントは 1 件（4 人・2 周）にして時間を短くする
  PAST_EVENTS = [ [ 14, 4, 2 ] ].freeze

  setup do
    MobileSuitCatalogSync.new.call
    MasterEmoji.create!(name: "いいね", image_key: "👍", position: 1, is_active: true)
  end

  test "サンプルユーザー・過去のイベント・開催中のイベントを作る" do
    summary = build

    assert_equal SampleData::USERS.size, summary.users
    assert_equal PAST_EVENTS.size + 1, summary.events
    assert_equal SampleData::USERS.map(&:third), User.order(:id).map { |user| user.user_favorite_suits.count }
    assert Rotation.where.not(id: active_rotation.id).none?(&:is_active?)
    assert Rotation.where.not(id: active_rotation.id).all? { |rotation| rotation.rotation_matches.where(match_id: nil).none? }
  end

  test "開催中のローテーションには、入力済み・未入力・スキップ・現在・予定の試合が揃う" do
    build
    rotation = active_rotation

    statuses = rotation.rotation_matches.map { |rotation_match| rotation_match.progress_status(rotation.current_match_index) }

    assert_equal %i[current pending recorded skipped upcoming], statuses.uniq.sort
  end

  test "詳細統計の撃墜数と被撃墜数が勝敗と食い違わない" do
    build

    Match.joins(:match_players).where.not(match_players: { score: nil }).distinct.includes(:match_players).find_each do |match|
      winners, losers = match.match_players.partition { |player| player.team_number == match.winning_team }
      assert_equal losers.sum(&:deaths), winners.sum(&:kills)
      assert_equal winners.sum(&:deaths), losers.sum(&:kills)
      assert_operator losers.sum(&:deaths), :>, 0
      assert_equal [ 1, 2, 3, 4 ], match.match_players.map(&:match_rank).sort
    end
  end

  test "同じ機体マスタなら毎回同じデータになる" do
    build
    first = snapshot
    RotationMatch.update_all(match_id: nil)
    [ Event, User, Announcement ].each(&:destroy_all)

    build

    assert_equal first, snapshot
  end

  private

  def build
    SampleData.new(past_events: PAST_EVENTS).call
  end

  def active_rotation
    Rotation.find_by!(is_active: true)
  end

  def snapshot
    MatchPlayer.joins(:user, :mobile_suit).order(:id).pluck("users.username", "mobile_suits.name", :score)
  end
end
