class PlayerDashboardTrendSnapshot < PlayerDashboardSnapshotBase
  def to_h
    {
      best_partners: best_partners,
      event_suit_trend: event_suit_trend,
      trend_event: trend_event,
      is_today_event: is_today_event,
      event_comparison: event_comparison,
      cost_analysis: cost_analysis,
      matchup_matrix: matchup_matrix
    }
  end

  private

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
      event_match_players_for_event = event_match_players(event.id)
      wins = win_count(event_match_players_for_event)
      stats_match_players_for_event = event_match_players_for_event.select(&:has_stats?)

      {
        event: event,
        total: event_match_players_for_event.size,
        wins: wins,
        losses: event_match_players_for_event.size - wins,
        win_rate: percentage(wins, event_match_players_for_event.size),
        is_today: event.held_on == Time.zone.today,
        avg_damage: average_event_damage(stats_match_players_for_event)
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
          judgment: judgment_for(win_rate)
        }
      end
      .sort_by { |cost| -cost[:win_rate] }
  end

  def matchup_matrix
    top_suit_ids = match_players.each_with_object(Hash.new(0)) do |match_player, usage|
      usage[match_player.mobile_suit_id] += 1
    end.sort_by { |_, count| -count }.take(3).map(&:first)

    top_suit_ids.filter_map do |mobile_suit_id|
      my_matches = match_players.select { |match_player| match_player.mobile_suit_id == mobile_suit_id }
      next if my_matches.empty?

      matchups = build_matchups(my_matches)
      next if matchups.empty?

      {
        my_suit: my_matches.first.mobile_suit,
        matchups: matchups
      }
    end
  end

  def average_event_damage(stats_match_players_for_event)
    return nil if stats_match_players_for_event.empty?

    average(stats_match_players_for_event) { |match_player| match_player.damage_dealt.to_i }.round(0).to_i
  end

  def judgment_for(win_rate)
    return "得意" if win_rate >= 60
    return "普通" if win_rate >= 40

    "苦手"
  end

  def build_matchups(my_matches)
    opponent_stats = Hash.new { |hash, key| hash[key] = { wins: 0, total: 0, mobile_suit: nil } }

    my_matches.each do |match_player|
      match_player.opponents.each do |opponent|
        opponent_stats[opponent.mobile_suit_id][:mobile_suit] = opponent.mobile_suit
        opponent_stats[opponent.mobile_suit_id][:total] += 1
        opponent_stats[opponent.mobile_suit_id][:wins] += 1 if match_player.won?
      end
    end

    opponent_stats
      .select { |_, stats| stats[:total] >= 2 }
      .map do |_, stats|
        win_rate = percentage(stats[:wins], stats[:total])
        {
          opponent_suit: stats[:mobile_suit],
          wins: stats[:wins],
          total: stats[:total],
          losses: stats[:total] - stats[:wins],
          win_rate: win_rate,
          compatibility: judgment_for(win_rate)
        }
      end
      .sort_by { |matchup| -matchup[:win_rate] }
      .take(5)
  end
end
