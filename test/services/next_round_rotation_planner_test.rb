require "test_helper"

class NextRoundRotationPlannerTest < ActiveSupport::TestCase
  # 周回境界をまたぐ連続休み試合数の上限（テンプレート内にもともとある最大連続休み以下）
  BOUNDARY_REST_LIMITS = { 4 => 0, 5 => 3, 6 => 2, 7 => 4, 8 => 3 }.freeze

  RotationTemplateCatalog.supported_counts.each do |player_count|
    test "#{player_count}人: 試合数と配信台回数の分布を前周から維持する" do
      previous = first_round(player_count)
      planned = plan(previous, [ previous ])

      assert_equal previous.size, planned.size
      assert_equal player_stats(previous).values.sort, player_stats(planned).values.sort
    end

    test "#{player_count}人: 周回境界をまたぐ連続休みが上限を超えない" do
      previous = first_round(player_count)
      planned = plan(previous, [ previous ])

      assert_operator boundary_rest(previous, planned), :<=, BOUNDARY_REST_LIMITS.fetch(player_count)
    end
  end

  [ 5, 7 ].each do |player_count|
    test "#{player_count}人: セットごとの休みプレイヤーが3周にわたって一致する" do
      rounds = [ first_round(player_count) ]
      2.times { rounds << plan(rounds.last, rounds) }

      assert set_resters(rounds.first, player_count).all? { |resters| resters.size == 1 }
      assert_equal 1, rounds.map { |round| set_resters(round, player_count) }.uniq.size
    end
  end

  [ 7, 8 ].each do |player_count|
    test "#{player_count}人: 2周目の対戦カードが1周目と重複しない" do
      previous = first_round(player_count)
      planned = plan(previous, [ previous ])

      assert_empty matchup_keys(previous) & matchup_keys(planned)
    end
  end

  [ 5, 6 ].each do |player_count|
    test "#{player_count}人: 2周目の配信パターンが1周目と重複しない" do
      previous = first_round(player_count)
      planned = plan(previous, [ previous ])

      assert_empty streaming_keys(previous) & streaming_keys(planned)
    end
  end

  test "プレイヤーの値をそのまま返す（User でも ID でもよい）" do
    previous = first_round(5).map { |row| row.map { |id| "user-#{id}" } }
    planned = plan(previous, [ previous ])

    assert_equal previous.flatten.uniq.sort, planned.flatten.uniq.sort
  end

  test "対応外の人数では nil を返す" do
    previous = [ [ 1, 2, 3, 4 ], [ 5, 6, 7, 8 ], [ 9, 1, 2, 3 ] ]

    assert_nil NextRoundRotationPlanner.new(previous_matches: previous, history_matches: previous).plan
  end

  test "前周の試合数がテンプレートと異なる場合は nil を返す" do
    previous = first_round(4).first(3)

    assert_nil NextRoundRotationPlanner.new(previous_matches: previous, history_matches: previous).plan
  end

  test "前周のセット別休みが崩れている場合は nil を返す" do
    previous = first_round(5)
    previous[0], previous[3] = previous[3], previous[0]

    assert_nil NextRoundRotationPlanner.new(previous_matches: previous, history_matches: previous).plan
  end

  private

  def rng
    @rng ||= Random.new(20260906)
  end

  def first_round(player_count)
    players = (1..player_count).to_a.shuffle(random: rng)
    to_rows(RotationGenerator.new(players).generate)
  end

  def plan(previous, history)
    planned = NextRoundRotationPlanner.new(
      previous_matches: previous,
      history_matches: history.flatten(1),
      random: rng
    ).plan
    assert_not_nil planned
    to_rows(planned)
  end

  def to_rows(match_data_list)
    match_data_list.sort_by { |data| data[:match_index] }.map { |data| data.values_at(*RotationGenerator::MATCH_PLAYER_KEYS) }
  end

  # プレイヤー => [試合数, 配信台回数]
  def player_stats(rows)
    rows.flatten.uniq.to_h do |player|
      [ player, [ rows.count { |row| row.include?(player) }, rows.count { |row| row.first == player } ] ]
    end
  end

  def set_resters(rows, player_count)
    players = rows.flatten.uniq
    rows.each_slice(RotationTemplateCatalog.matches_per_set(player_count)).map { |set| (players - set.flatten).sort }
  end

  def boundary_rest(previous, planned)
    previous.flatten.uniq.map do |player|
      previous.reverse.take_while { |row| !row.include?(player) }.size +
        planned.take_while { |row| !row.include?(player) }.size
    end.max
  end

  def matchup_keys(rows)
    rows.map { |row| [ row[0, 2].sort, row[2, 2].sort ].sort }
  end

  def streaming_keys(rows)
    rows.map { |row| [ row[0], row[1], row[2, 2].sort ] }
  end
end
