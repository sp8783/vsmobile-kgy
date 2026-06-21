class PlayerDashboardPerformanceSnapshot < PlayerDashboardSnapshotBase
  def to_h
    {
      performance_snapshot: performance_snapshot,
      community_snapshot: community_snapshot,
      highlight_best_damage_mp: highlight_best_damage_mp,
      highlight_best_kd_mp: highlight_best_kd_mp,
      exburst_summary: exburst_summary
    }
  end

  private

  def performance_snapshot
    return nil if stats_match_players.empty?

    total_deaths = stats_match_players.sum { |match_player| match_player.deaths.to_i }

    {
      avg_score: average(stats_match_players) { |match_player| match_player.score.to_i }.round(1),
      avg_damage: average(stats_match_players) { |match_player| match_player.damage_dealt.to_i }.round(0).to_i,
      kd_ratio: total_deaths.positive? ? (stats_match_players.sum { |match_player| match_player.kills.to_i }.to_f / total_deaths).round(2) : nil,
      avg_exburst_damage: average(stats_match_players) { |match_player| match_player.exburst_damage.to_i }.round(0).to_i
    }
  end

  def community_snapshot
    community_base = MatchPlayer.joins(:user).where(users: { is_guest: false }).where.not(damage_dealt: nil)
    return nil unless community_base.exists?

    {
      avg_score: community_base.average(:score)&.round(1),
      avg_damage: community_base.average(:damage_dealt)&.round(0)&.to_i,
      avg_damage_received: community_base.average(:damage_received)&.round(0)&.to_i,
      avg_exburst_damage: community_base.average(:exburst_damage)&.round(0)&.to_i
    }
  end

  def highlight_best_damage_mp
    positive_damage_match_players.max_by { |match_player| match_player.damage_dealt.to_i }
  end

  def highlight_best_kd_mp
    kd_match_players = positive_damage_match_players.select do |match_player|
      match_player.kills.to_i.positive? || match_player.deaths.to_i.positive?
    end
    kd_match_players.max_by do |match_player|
      match_player.kills.to_f / [ match_player.deaths.to_i, 1 ].max
    end
  end

  def exburst_summary
    exburst_match_players = match_players.select { |match_player| match_player.exburst_count.present? }
    return nil if exburst_match_players.empty?

    total_deaths = exburst_match_players.sum { |match_player| match_player.deaths.to_i }

    {
      avg_count: average(exburst_match_players) { |match_player| match_player.exburst_count.to_i }.round(2),
      avg_damage: average(exburst_match_players) { |match_player| match_player.exburst_damage.to_i }.round(0).to_i,
      death_rate: total_deaths.positive? ? (exburst_match_players.sum { |match_player| match_player.exburst_deaths.to_i }.to_f / total_deaths * 100).round(1) : 0.0,
      community_avg_count: MatchPlayer.joins(:user).where(users: { is_guest: false }).where.not(exburst_count: nil).average(:exburst_count)&.round(2)
    }
  end
end
