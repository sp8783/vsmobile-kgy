class PlayerDashboardSnapshot
  def initialize(user:, match_players:)
    @user = user
    @match_players = match_players.to_a
  end

  def to_h
    personal_stats.merge(
      recent_matches: recent_matches,
      user_favorite_suits: user_favorite_suits,
      recent_5_results: recent_5_results,
      recent_10_win_rate: recent_10_win_rate,
      recent_10_diff: recent_10_diff,
      current_streak: current_streak,
      streak_type: streak_type,
      best_partners: best_partners,
      event_suit_trend: event_suit_trend,
      trend_event: trend_event,
      is_today_event: is_today_event,
      event_comparison: event_comparison,
      cost_analysis: cost_analysis,
      performance_snapshot: performance_snapshot,
      community_snapshot: community_snapshot,
      highlight_best_damage_mp: highlight_best_damage_mp,
      highlight_best_kd_mp: highlight_best_kd_mp,
      exburst_summary: exburst_summary,
      matchup_matrix: matchup_matrix
    )
  end

  private

  attr_reader :user, :match_players

  def personal_stats
    wins = win_count(match_players)
    stats_match_players = match_players.select(&:has_stats?)
    total_deaths = stats_match_players.sum { |match_player| match_player.deaths.to_i }

    {
      user_total_matches: match_players.size,
      user_wins: wins,
      user_win_rate: percentage(wins, match_players.size),
      user_has_stats: stats_match_players.any?,
      user_avg_damage: stats_match_players.any? ? average(stats_match_players) { |match_player| match_player.damage_dealt.to_i }.round(0).to_i : nil,
      user_avg_kd: total_deaths.positive? ? (stats_match_players.sum { |match_player| match_player.kills.to_i }.to_f / total_deaths).round(2) : nil
    }
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
              .map do |mobile_suit, stats|
                decorate_mobile_suit(mobile_suit, stats)
              end
  end

  def recent_5_results
    recent_unique_match_players(limit: 10).take(5).map(&:won?)
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

  def best_partners
    partner_stats = {}

    match_players.each do |match_player|
      partner = match_player.partner
      next unless partner

      partner_stats[partner.user_id] ||= {
        user: partner.user,
        wins: 0,
        total: 0,
        suit_combinations: Hash.new(0)
      }

      partner_stats[partner.user_id][:wins] += 1 if match_player.won?
      partner_stats[partner.user_id][:total] += 1
      combo_key = "#{match_player.mobile_suit.name} & #{partner.mobile_suit.name}"
      partner_stats[partner.user_id][:suit_combinations][combo_key] += 1
    end

    partner_stats
      .select { |_, stats| stats[:total] >= 3 }
      .map do |_, stats|
        {
          user: stats[:user],
          win_rate: percentage(stats[:wins], stats[:total]),
          wins: stats[:wins],
          total: stats[:total],
          best_combo: stats[:suit_combinations].max_by { |_, count| count }&.first
        }
      end
      .sort_by { |partner| -partner[:win_rate] }
      .take(3)
  end

  def event_suit_trend
    return nil unless trend_event

    suit_stats = {}

    event_match_players(trend_event.id).each do |match_player|
      suit_stats[match_player.mobile_suit_id] ||= {
        mobile_suit: match_player.mobile_suit,
        usage: 0,
        wins: 0
      }

      suit_stats[match_player.mobile_suit_id][:usage] += 1
      suit_stats[match_player.mobile_suit_id][:wins] += 1 if match_player.won?
    end

    suit_stats.map do |_, stats|
      {
        mobile_suit: stats[:mobile_suit],
        usage: stats[:usage],
        win_rate: percentage(stats[:wins], stats[:usage]),
        recommended: percentage(stats[:wins], stats[:usage]) >= 60
      }
    end.sort_by { |suit| -suit[:usage] }
  end

  def trend_event
    @trend_event ||= Event.find_by(held_on: Time.zone.today) || Event.order(held_on: :desc).first
  end

  def is_today_event
    trend_event&.held_on == Time.zone.today
  end

  def event_comparison
    Event.order(held_on: :desc).limit(3).map do |event|
      event_match_players = event_match_players(event.id)
      wins = win_count(event_match_players)
      stats_match_players = event_match_players.select(&:has_stats?)

      {
        event: event,
        total: event_match_players.size,
        wins: wins,
        losses: event_match_players.size - wins,
        win_rate: percentage(wins, event_match_players.size),
        is_today: event.held_on == Time.zone.today,
        avg_damage: stats_match_players.any? ? average(stats_match_players) { |match_player| match_player.damage_dealt.to_i }.round(0).to_i : nil
      }
    end
  end

  def cost_analysis
    cost_stats = Hash.new { |hash, key| hash[key] = { wins: 0, total: 0 } }

    match_players.each do |match_player|
      partner = match_player.partner
      next unless partner

      costs = [ match_player.mobile_suit.cost, partner.mobile_suit.cost ].sort.reverse
      cost_key = "#{costs[0]}+#{costs[1]}"

      cost_stats[cost_key][:total] += 1
      cost_stats[cost_key][:wins] += 1 if match_player.won?
    end

    cost_stats
      .select { |_, stats| stats[:total] >= 3 }
      .map do |cost_key, stats|
        win_rate = percentage(stats[:wins], stats[:total])
        {
          cost_combo: cost_key,
          wins: stats[:wins],
          total: stats[:total],
          losses: stats[:total] - stats[:wins],
          win_rate: win_rate,
          judgment: win_rate >= 60 ? "得意" : (win_rate >= 40 ? "普通" : "苦手")
        }
      end
      .sort_by { |cost| -cost[:win_rate] }
  end

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
    kd_match_players.max_by { |match_player| match_player.kills.to_f / [ match_player.deaths.to_i, 1 ].max }
  end

  def exburst_summary
    exburst_match_players = match_players.select { |match_player| match_player.exburst_count.present? }
    return nil if exburst_match_players.empty?

    total = exburst_match_players.size
    total_deaths = exburst_match_players.sum { |match_player| match_player.deaths.to_i }

    {
      avg_count: average(exburst_match_players) { |match_player| match_player.exburst_count.to_i }.round(2),
      avg_damage: average(exburst_match_players) { |match_player| match_player.exburst_damage.to_i }.round(0).to_i,
      death_rate: total_deaths.positive? ? (exburst_match_players.sum { |match_player| match_player.exburst_deaths.to_i }.to_f / total_deaths * 100).round(1) : 0.0,
      community_avg_count: MatchPlayer.joins(:user).where(users: { is_guest: false }).where.not(exburst_count: nil).average(:exburst_count)&.round(2)
    }
  end

  def matchup_matrix
    top_suit_ids = match_players.each_with_object(Hash.new(0)) do |match_player, usage|
      usage[match_player.mobile_suit_id] += 1
    end.sort_by { |_, count| -count }.take(3).map(&:first)

    top_suit_ids.filter_map do |mobile_suit_id|
      my_matches = match_players.select { |match_player| match_player.mobile_suit_id == mobile_suit_id }
      next if my_matches.empty?

      opponent_stats = Hash.new { |hash, key| hash[key] = { wins: 0, total: 0, mobile_suit: nil } }

      my_matches.each do |match_player|
        match_player.opponents.each do |opponent|
          opponent_stats[opponent.mobile_suit_id][:mobile_suit] = opponent.mobile_suit
          opponent_stats[opponent.mobile_suit_id][:total] += 1
          opponent_stats[opponent.mobile_suit_id][:wins] += 1 if match_player.won?
        end
      end

      matchups = opponent_stats
                   .select { |_, stats| stats[:total] >= 2 }
                   .map do |_, stats|
                     win_rate = percentage(stats[:wins], stats[:total])
                     {
                       opponent_suit: stats[:mobile_suit],
                       wins: stats[:wins],
                       total: stats[:total],
                       losses: stats[:total] - stats[:wins],
                       win_rate: win_rate,
                       compatibility: win_rate >= 60 ? "得意" : (win_rate >= 40 ? "普通" : "苦手")
                     }
                   end
                   .sort_by { |matchup| -matchup[:win_rate] }
                   .take(5)

      next if matchups.empty?

      {
        my_suit: my_matches.first.mobile_suit,
        matchups: matchups
      }
    end
  end

  def stats_match_players
    @stats_match_players ||= match_players.select(&:has_stats?)
  end

  def positive_damage_match_players
    @positive_damage_match_players ||= stats_match_players.select { |match_player| match_player.damage_dealt.to_i > 0 }
  end

  def recent_10_results
    @recent_10_results ||= unique_recent_match_players(limit: 10).map(&:won?)
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

  def unique_recent_match_players(limit: nil)
    seen_match_ids = {}
    unique_match_players = []

    match_players.each do |match_player|
      next if seen_match_ids[match_player.match_id]

      seen_match_ids[match_player.match_id] = true
      unique_match_players << match_player
      break if limit && unique_match_players.size >= limit
    end

    unique_match_players
  end

  def event_match_players(event_id)
    match_players.select { |match_player| match_player.match.event_id == event_id }
  end

  def win_count(match_players)
    match_players.count(&:won?)
  end

  def decorate_mobile_suit(mobile_suit, stats)
    win_rate = percentage(stats[:wins], stats[:count])

    mobile_suit.tap do |suit|
      suit.define_singleton_method(:usage_count) { stats[:count] }
      suit.define_singleton_method(:win_rate) { win_rate }
    end
  end

  def average(match_players, &block)
    match_players.sum(&block).to_f / match_players.size
  end

  def percentage(numerator, denominator)
    denominator.positive? ? (numerator.to_f / denominator * 100).round(1) : 0
  end
end
