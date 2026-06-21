class StatisticsPersonalTabSnapshotBase
  def initialize(filtered_matches:, filtered_matches_relation: nil)
    @filtered_matches = filtered_matches
    @filtered_matches_relation = filtered_matches_relation
  end

  private

  attr_reader :filtered_matches, :filtered_matches_relation

  def ordered_match_players
    @ordered_match_players ||= if filtered_matches_relation.respond_to?(:order)
      filtered_matches_relation.order("matches.played_at ASC").to_a
    else
      filtered_matches.sort_by { |match_player| [ match_sort_time(match_player), match_player.match.id ] }
    end
  end

  def average(match_players, field)
    values = match_players.filter_map { |match_player| match_player.public_send(field)&.to_f }
    return nil if values.empty?

    values.sum / values.size
  end

  def kd_ratio(avg_kills, avg_deaths)
    return nil unless avg_kills
    return avg_kills.round(2) unless avg_deaths&.positive?

    (avg_kills / avg_deaths).round(2)
  end

  def top_entries(values)
    values.sort_by { |_, count| -count }.take(3).to_h
  end

  def latest_time(current_time, candidate_time)
    return current_time unless candidate_time
    return candidate_time if current_time.nil? || candidate_time > current_time

    current_time
  end

  def percentage(numerator, denominator)
    denominator.positive? ? (numerator.to_f / denominator * 100).round(1) : 0
  end

  def match_sort_time(match_player)
    match_player.match.played_at || Time.zone.at(0)
  end
end
