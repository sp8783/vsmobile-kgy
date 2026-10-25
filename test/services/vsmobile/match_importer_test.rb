require "test_helper"

# 届いた 1 試合分の統計データを、イベントのどの試合かを決めて取り込む
class Vsmobile::MatchImporterTest < ActiveSupport::TestCase
  include RotationTestHelper

  FIRST_TS = Time.zone.local(2026, 11, 7, 10, 12, 5).to_i

  setup do
    @players = build_players(%w[A B C D E])
    @event = Event.create!(name: "テスト対戦会", held_on: Date.new(2026, 11, 7))
    # 同じ 4 人・同じチーム分け（A&B vs C&D）が 2 回、別の組（A&E vs B&C）が 1 回
    @m1 = create_match(%w[A B], %w[C D], played_at: Time.zone.local(2026, 11, 7, 10, 20))
    @m2 = create_match(%w[A E], %w[B C], played_at: Time.zone.local(2026, 11, 7, 10, 27))
    @m3 = create_match(%w[C D], %w[A B], played_at: Time.zone.local(2026, 11, 7, 10, 34), winning_team: 2)
  end

  test "同じ 4 人組の試合を、開始時刻の順と登録順の k 番目で対応づける" do
    first = import(FIRST_TS, %w[Aさん Bさん], %w[Cさん Dさん])
    second = import(FIRST_TS + 900, %w[Cさん Dさん], %w[Aさん Bさん], submitted_by: @players["C"])

    assert_equal :imported, first.status
    assert_equal @m1, first.match
    assert_equal :imported, second.status
    assert_equal @m3, second.match, "チームの左右が入れ替わっていても同じ組として扱う"
    assert_equal Time.zone.at(FIRST_TS), @m1.reload.game_started_at
    assert_equal 1500, @m1.match_players.find_by(user: @players["A"]).score
    assert_equal @players["C"], @m3.reload.stats_payload.submitted_by
    assert_nil @m1.stats_payload.submitted_by, "一括取得は送った人なし"
  end

  test "2 回目の試合だけが先に届いても、1 回目が届いたときに前に入る" do
    import(FIRST_TS + 900, %w[Aさん Bさん], %w[Cさん Dさん])
    result = import(FIRST_TS, %w[Aさん Bさん], %w[Cさん Dさん])

    # 先に届いた方は k=0 で 1 回目の試合に入ってしまうので、あとから届いた早い試合は残っている方に入る
    assert_equal :imported, result.status
    assert_equal @m3, result.match
  end

  test "同じ開始時刻の試合が既にあれば、先に届いた方を正として触らない" do
    import(FIRST_TS, %w[Aさん Bさん], %w[Cさん Dさん], submitted_by: @players["A"])
    result = import(FIRST_TS, %w[Aさん Bさん], %w[Cさん Dさん], submitted_by: @players["C"])

    assert_equal :already, result.status
    assert_equal @m1, result.match
    assert_equal @players["A"], @m1.reload.stats_payload.submitted_by
  end

  test "4 人の組がイベントにない（ニックネームが違う）ときは理由つきで失敗する" do
    error = assert_raises(Vsmobile::MatchImporter::NoMatchError) { import(FIRST_TS, %w[Aさん Zさん], %w[Cさん Dさん]) }

    assert_match "Aさん・Zさん・Cさん・Dさん の試合がイベントに見つかりません", error.message
    assert_match "ニックネーム", error.message
  end

  test "その組の試合がすべて取り込み済みなら失敗する" do
    import(FIRST_TS, %w[Aさん Eさん], %w[Bさん Cさん])

    error = assert_raises(Vsmobile::MatchImporter::NoMatchError) { import(FIRST_TS + 100, %w[Aさん Eさん], %w[Bさん Cさん]) }
    assert_match "すべて取り込み済み", error.message
  end

  test "開始時刻がなければ失敗する" do
    assert_raises(Vsmobile::MatchImporter::NoMatchError) { Vsmobile::MatchImporter.new(event: @event, parsed: payload(nil, %w[Aさん Bさん], %w[Cさん Dさん])).import! }
  end

  private

  def import(match_ts, team_a, team_b, submitted_by: nil)
    Vsmobile::MatchImporter.new(event: @event, parsed: payload(match_ts, team_a, team_b), submitted_by: submitted_by).import!
  end

  def payload(match_ts, team_a, team_b)
    {
      "match_ts" => match_ts,
      "team_a" => { "players" => team_a.map { |name| { "name" => name, "score" => 1500, "kills" => 2, "deaths" => 1, "damage_dealt" => 700, "damage_received" => 500, "exburst_damage" => 100 } } },
      "team_b" => { "players" => team_b.map { |name| { "name" => name, "score" => 900, "kills" => 1, "deaths" => 2, "damage_dealt" => 500, "damage_received" => 700, "exburst_damage" => 50 } } },
      "timeline_raw" => { "groups" => {}, "events" => [], "game_end_cs" => 12000, "game_end_str" => "2:00.00" }
    }
  end

  def create_match(team1, team2, played_at:, winning_team: 1)
    suit = MobileSuit.first || MobileSuit.create!(name: "テスト機体", series: "テスト", cost: 3000)
    attributes = (team1 + team2).each_with_index.map do |name, index|
      { user: @players.fetch(name), mobile_suit: suit, team_number: index < 2 ? 1 : 2, position: index + 1 }
    end
    @event.matches.create!(played_at: played_at, winning_team: winning_team, match_players_attributes: attributes)
  end
end
