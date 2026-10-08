# 次周（2周目以降）のローテーション表を組む。
#
# 前周のセット別の休みプレイヤーを固定したまま、プレイヤーとテンプレートスロットの対応を探索し、
# 以下の優先順でスコアが最小になる割り当てを採用する。同点の候補からはランダムに選ぶ。
#   1. 周回境界をまたぐ連続休み試合数（前周末尾の休み + 次周先頭の休み）の最大値
#   2. 同イベントの過去周と同一の対戦カード（ペア × 相手ペア）の数
#   3. 同イベントの過去周と同一の配信パターン（配信者 + パートナー + 相手ペア）の数
#
# previous_matches / history_matches の各要素は [team1_player1, team1_player2, team2_player1, team2_player2]
# のプレイヤー配列（match_index 順。値は User でも ID でもよい）。history_matches には前周を含める。
# 前周が想定構造でない場合、plan は nil を返す。
class NextRoundRotationPlanner
  EXHAUSTIVE_SEARCH_MAX_PLAYERS = 7
  SAMPLE_SIZE = 2000

  def initialize(previous_matches:, history_matches:, random: Random.new)
    @previous_matches = previous_matches
    @history_matches = history_matches
    @random = random
  end

  # RotationGenerator#generate と同形式の Hash 配列を返す
  def plan
    return nil unless plannable?

    best = nil
    best_score = nil
    ties = 0

    candidate_assignments.each do |assignment|
      matches = build_matches(assignment)
      score = score_for(matches)
      comparison = best_score ? (score <=> best_score) : -1

      if comparison.negative?
        best = matches
        best_score = score
        ties = 1
      elsif comparison.zero?
        ties += 1
        best = matches if random.rand < 1.0 / ties
      end
    end

    to_match_data(best)
  end

  private

  attr_reader :previous_matches, :history_matches, :random

  # ---- 入力の正規化（プレイヤーを 0...player_count の番号に置き換える） ----

  def players
    @players ||= previous_matches.flatten.uniq
  end

  def player_count
    players.size
  end

  def player_index
    @player_index ||= players.each_with_index.to_h
  end

  def previous_by_index
    @previous_by_index ||= previous_matches.map { |match| match.map { |player| player_index.fetch(player) } }
  end

  # 過去周の試合のうち、今回の参加プレイヤーのみで構成されるもの
  def history_by_index
    @history_by_index ||= history_matches.filter_map do |match|
      indexes = match.map { |player| player_index[player] }
      indexes if indexes.none?(&:nil?)
    end
  end

  # ---- テンプレート ----

  def template
    @template ||= RotationTemplateCatalog.fetch(player_count).map(&:flatten)
  end

  def matches_per_set
    RotationTemplateCatalog.matches_per_set(player_count)
  end

  def template_sets
    @template_sets ||= template.each_slice(matches_per_set).to_a
  end

  # テンプレートの各セットで全休するスロット（5人・7人はセットごとに1スロット、それ以外は空）
  def template_set_resters
    @template_set_resters ||= template_sets.map { |set| (0...player_count).to_a - set.flatten }
  end

  def set_level_rest?
    template_set_resters.all? { |resters| resters.size == 1 }
  end

  def template_set_index_by_rester_slot
    @template_set_index_by_rester_slot ||= template_set_resters.each_with_index.to_h { |(slot), set_index| [ slot, set_index ] }
  end

  # 前周の各セットで全休したプレイヤー番号
  def previous_set_resters
    @previous_set_resters ||= previous_by_index.each_slice(matches_per_set).map { |set| (0...player_count).to_a - set.flatten }
  end

  def plannable?
    return false unless RotationTemplateCatalog.supported_counts.include?(player_count)
    return false unless previous_matches.size == template.size
    return true unless set_level_rest?

    previous_set_resters.all? { |resters| resters.size == 1 } && previous_set_resters.flatten.uniq.size == player_count
  end

  # ---- 候補の列挙と構築 ----

  # assignment[slot] = プレイヤー番号
  def candidate_assignments
    indexes = (0...player_count).to_a
    if player_count <= EXHAUSTIVE_SEARCH_MAX_PLAYERS
      indexes.permutation
    else
      Array.new(SAMPLE_SIZE) { indexes.shuffle(random: random) }
    end
  end

  def build_matches(assignment)
    ordered_template = set_level_rest? ? reorder_sets_for(assignment) : template
    ordered_template.map { |slots| slots.map { |slot| assignment[slot] } }
  end

  # 前周と同じセット位置で同じプレイヤーが全休するように、テンプレートのセット順を並べ替える
  def reorder_sets_for(assignment)
    slot_of = assignment.each_with_index.to_h
    previous_set_resters.flat_map do |(rester)|
      template_sets[template_set_index_by_rester_slot.fetch(slot_of.fetch(rester))]
    end
  end

  # ---- スコアリング ----

  def score_for(matches)
    [ boundary_rest_score(matches), matchup_duplicates(matches), streaming_duplicates(matches) ]
  end

  def boundary_rest_score(matches)
    (0...player_count).map { |player| trailing_rests.fetch(player) + leading_rests(matches, player) }.max
  end

  def trailing_rests
    @trailing_rests ||= (0...player_count).to_h do |player|
      [ player, previous_by_index.reverse.take_while { |match| !match.include?(player) }.size ]
    end
  end

  def leading_rests(matches, player)
    matches.take_while { |match| !match.include?(player) }.size
  end

  def matchup_duplicates(matches)
    matches.sum { |match| history_matchup_counts[matchup_key(match)] }
  end

  def streaming_duplicates(matches)
    matches.sum { |match| history_streaming_counts[streaming_key(match)] }
  end

  def history_matchup_counts
    @history_matchup_counts ||= history_by_index.each_with_object(Hash.new(0)) do |match, counts|
      counts[matchup_key(match)] += 1
    end
  end

  def history_streaming_counts
    @history_streaming_counts ||= history_by_index.each_with_object(Hash.new(0)) do |match, counts|
      counts[streaming_key(match)] += 1
    end
  end

  # ペア × 相手ペア（チームの左右・席順は区別しない）
  def matchup_key(match)
    [ match[0, 2].sort, match[2, 2].sort ].sort
  end

  # 配信者 + パートナー + 相手ペア
  def streaming_key(match)
    [ match[0], match[1], match[2, 2].sort ]
  end

  # ---- 出力 ----

  def to_match_data(matches)
    matches.each_with_index.map do |indexes, match_index|
      { match_index: match_index }.merge(
        RotationGenerator::MATCH_PLAYER_KEYS.zip(indexes).to_h { |key, index| [ key, players[index] ] }
      )
    end
  end
end
