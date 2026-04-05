class StatisticsPersonalOverviewSnapshot < StatisticsPersonalTabSnapshotBase
  def to_h
    wins = filtered_matches.count(&:won?)
    total = filtered_matches.size

    {
      total_matches: total,
      total_wins: wins,
      win_rate: percentage(wins, total),
      max_winning_streak: max_winning_streak,
      event_win_rates: event_win_rates,
      cost_win_rates: cost_win_rates,
      rotation_round_stats: rotation_round_stats
    }
  end

  private

  def max_winning_streak
    max_streak = 0
    current_streak = 0

    ordered_match_players.each do |match_player|
      if match_player.won?
        current_streak += 1
        max_streak = [ max_streak, current_streak ].max
      else
        current_streak = 0
      end
    end

    max_streak
  end

  def event_win_rates
    event_data = Hash.new { |hash, key| hash[key] = { event: nil, wins: 0, total: 0 } }

    filtered_matches.each do |match_player|
      event = match_player.match.event
      entry = event_data[event.id]
      entry[:event] = event
      entry[:total] += 1
      entry[:wins] += 1 if match_player.won?
    end

    event_data.values.map do |entry|
      {
        event: entry[:event],
        win_rate: percentage(entry[:wins], entry[:total]),
        total: entry[:total]
      }
    end.sort_by { |entry| entry[:event].held_on }
  end

  def cost_win_rates
    cost_data = Hash.new { |hash, key| hash[key] = { wins: 0, total: 0 } }

    filtered_matches.each do |match_player|
      partner_cost = match_player.partner&.mobile_suit&.cost
      entry = cost_data[[ match_player.mobile_suit.cost, partner_cost ]]
      entry[:total] += 1
      entry[:wins] += 1 if match_player.won?
    end

    cost_data.map do |(my_cost, partner_cost), entry|
      {
        my_cost: my_cost,
        partner_cost: partner_cost,
        wins: entry[:wins],
        losses: entry[:total] - entry[:wins],
        total: entry[:total],
        win_rate: percentage(entry[:wins], entry[:total])
      }
    end.sort_by { |entry| [ -entry[:my_cost], -(entry[:partner_cost] || 0) ] }
  end

  def rotation_round_stats
    round_data = Hash.new { |hash, key| hash[key] = { wins: 0, total: 0 } }

    filtered_matches.each do |match_player|
      round_number = match_player.match.rotation_match&.rotation&.round_number
      next unless round_number

      entry = round_data[round_number]
      entry[:total] += 1
      entry[:wins] += 1 if match_player.won?
    end

    round_data.map do |round_number, entry|
      {
        round_number: round_number,
        wins: entry[:wins],
        total: entry[:total],
        losses: entry[:total] - entry[:wins],
        win_rate: percentage(entry[:wins], entry[:total])
      }
    end.sort_by { |entry| entry[:round_number] }
  end
end
