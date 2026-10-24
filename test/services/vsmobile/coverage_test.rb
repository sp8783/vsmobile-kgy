require "test_helper"

# 各試合の統計がどこまで届いたか、足りない試合を誰が送れば埋まるか
class Vsmobile::CoverageTest < ActiveSupport::TestCase
  include RotationTestHelper

  setup do
    @players = build_players(%w[A B C D E F])
    @event = Event.create!(name: "テスト対戦会", held_on: Date.new(2026, 11, 7))
    @m1 = create_match(%w[A B], %w[C D])
    @m2 = create_match(%w[A E], %w[B F])
    @m3 = create_match(%w[C E], %w[D F])
    @m4 = create_match(%w[A C], %w[E F])
    @coverage = Vsmobile::Coverage.new(event: @event)
  end

  test "何も届いていなければ、全員が候補で、埋まる試合数の多い順に並ぶ" do
    assert_equal 0, @coverage.covered_count
    assert_equal [ 1, 2, 3, 4 ], @coverage.missing_numbers
    # E と F は第 2・3・4 試合、A は第 1・2・4、C は第 1・3・4
    assert_equal [ "Aさん", "Cさん", "Eさん", "Fさん", "Bさん", "Dさん" ], @coverage.candidates.map { |c| c.user.nickname }
    assert_equal [ 1, 2, 4 ], @coverage.candidate_for(@players["A"]).match_numbers
  end

  test "届いた試合を除いて候補と最少人数を出す" do
    import(@m1, submitted_by: @players["A"])
    import(@m4, submitted_by: nil)

    assert_equal 2, @coverage.covered_count
    assert_equal [ 2, 3 ], @coverage.missing_numbers
    assert @coverage.participant?(@players["A"])
    assert @coverage.submitted?(@players["A"])
    assert_not @coverage.submitted?(@players["E"])
    assert_equal [ @players["A"] ], @coverage.submitters
    assert_equal %w[Bさん Cさん Dさん Eさん Fさん], @coverage.not_submitted.map(&:nickname)
    assert @coverage.bulk_imported?
    assert_equal "Aさんのデータ", @coverage.source_label(@m1)
    assert_equal "取り込み済み", @coverage.source_label(@m4)
    assert_nil @coverage.source_label(@m2)
  end

  test "送った人のいない統計は「取り込み済み」で、全部そろえば候補なし" do
    [ @m1, @m2, @m3, @m4 ].each { |match| match.create_match_timeline!(timeline_raw: { "groups" => {}, "events" => [] }) }

    assert @coverage.complete?
    assert_equal [], @coverage.missing_numbers
    assert_equal [], @coverage.candidates
    assert_equal "取り込み済み", @coverage.source_label(@m1)
  end

  test "ゲストは候補にしない" do
    @players["B"].update!(is_guest: true)

    assert_nil @coverage.candidate_for(@players["B"])
  end

  private

  def import(match, submitted_by:)
    match.create_match_timeline!(timeline_raw: { "groups" => {}, "events" => [] })
    match.create_stats_payload!(payload: { "match_ts" => 1 }, submitted_by: submitted_by, submitted_at: Time.current)
  end

  def create_match(team1, team2)
    suit = MobileSuit.first || MobileSuit.create!(name: "テスト機体", series: "テスト", cost: 3000)
    attributes = (team1 + team2).each_with_index.map do |name, index|
      { user: @players.fetch(name), mobile_suit: suit, team_number: index < 2 ? 1 : 2, position: index + 1 }
    end
    @event.matches.create!(played_at: Time.zone.local(2026, 11, 7, 10, 20) + (@event.matches.count * 7).minutes, winning_team: 1, match_players_attributes: attributes)
  end
end
