class PlayerDashboardSummarySnapshot < PlayerDashboardSnapshotBase
  def to_h
    personal_stats.merge(
      recent_matches: recent_matches,
      user_favorite_suits: user_favorite_suits,
      recent_5_results: recent_5_results,
      recent_10_results: recent_10_results,
      recent_10_win_rate: recent_10_win_rate,
      recent_10_diff: recent_10_diff,
      current_streak: current_streak,
      streak_type: streak_type
    )
  end

  private

  def personal_stats
    wins = win_count(match_players)
    total_deaths = stats_match_players.sum { |match_player| match_player.deaths.to_i }

    {
      user_total_matches: match_players.size,
      user_wins: wins,
      user_win_rate: percentage(wins, match_players.size),
      user_has_stats: stats_match_players.any?,
      user_avg_damage: average_damage,
      user_avg_damage_received: average_damage_received,
      user_avg_kd: average_kd(total_deaths),
      user_suits_used: distinct_suits_used
    }
  end

  def distinct_suits_used
    match_players.map(&:mobile_suit_id).uniq.size
  end

  def average_damage_received
    return nil if stats_match_players.empty?

    average(stats_match_players) { |match_player| match_player.damage_received.to_i }.round(0).to_i
  end

  def recent_matches
    unique_recent_match_players(limit: 5).map(&:match)
  end

  def user_favorite_suits
    suit_stats = Hash.new { |hash, mobile_suit| hash[mobile_suit] = { count: 0, wins: 0 } }

    match_players.each do |match_player|
      suit_stats[match_player.mobile_suit][:count] += 1
      suit_stats[match_player.mobile_suit][:wins] += 1 if match_player.won?
    end

    suit_stats.sort_by { |_, stats| -stats[:count] }
              .take(3)
              .map { |mobile_suit, stats| decorate_mobile_suit(mobile_suit, stats) }
  end

  def recent_5_results
    recent_10_results.take(5)
  end

  def recent_10_win_rate
    return 0 if recent_10_results.empty?

    percentage(recent_10_results.count(true), recent_10_results.size)
  end

  def recent_10_diff
    recent_10_win_rate - personal_stats[:user_win_rate]
  end

  def current_streak
    streak_state[:count]
  end

  def streak_type
    streak_state[:type]
  end

  def average_damage
    return nil if stats_match_players.empty?

    average(stats_match_players) { |match_player| match_player.damage_dealt.to_i }.round(0).to_i
  end

  def average_kd(total_deaths)
    return nil unless total_deaths.positive?

    (stats_match_players.sum { |match_player| match_player.kills.to_i }.to_f / total_deaths).round(2)
  end

  def streak_state
    @streak_state ||= begin
      count = 0
      type = nil

      unique_recent_match_players.each do |match_player|
        is_win = match_player.won?

        if type.nil?
          type = is_win ? "win" : "lose"
          count = 1
        elsif (type == "win" && is_win) || (type == "lose" && !is_win)
          count += 1
        else
          break
        end
      end

      { count: count, type: type }
    end
  end
end
