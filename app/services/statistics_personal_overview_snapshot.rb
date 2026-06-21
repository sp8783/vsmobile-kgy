class StatisticsPersonalOverviewSnapshot < StatisticsPersonalTabSnapshotBase
  def to_h
    wins = filtered_matches.count(&:won?)
    total = filtered_matches.size

    {
      total_matches: total,
      total_wins: wins,
      win_rate: percentage(wins, total),
      max_winning_streak: max_winning_streak_data[:count],
      max_winning_streak_event: max_winning_streak_data[:event]&.name,
      event_win_rates: event_win_rates,
      cost_solo_stats: cost_solo_stats,
      cost_win_rates: cost_win_rates,
      rotation_round_stats: rotation_round_stats,
      overview_suits_used: suits_used,
      overview_community_suits_used: community_suits_used_avg,
      overview_avg_damage_dealt: avg_damage_dealt,
      overview_avg_damage_received: avg_damage_received,
      overview_community_damage_dealt: community_damage_dealt,
      overview_community_damage_received: community_damage_received,
      overview_top_suits: top_suits,
      overview_best_partners: best_partners,
      overview_matchup_strong: matchup_strong,
      overview_matchup_weak: matchup_weak,
      overview_best_records: best_records
    }
  end

  private

  MATCHUP_MIN_GAMES = 5

  def stats_matches
    @stats_matches ||= filtered_matches.select(&:has_stats?)
  end

  def suits_used
    filtered_matches.map(&:mobile_suit_id).uniq.size
  end

  # 非ゲストプレイヤー1人あたりの平均使用機体数（全体比の基準）
  def community_suits_used_avg
    counts = MatchPlayer.joins(:user).where(users: { is_guest: false }).group(:user_id).count("DISTINCT mobile_suit_id")
    return nil if counts.empty?

    (counts.values.sum.to_f / counts.size).round(1)
  end

  def avg_damage_dealt
    average(stats_matches, :damage_dealt)&.round(0)&.to_i
  end

  def avg_damage_received
    average(stats_matches, :damage_received)&.round(0)&.to_i
  end

  def community_base
    MatchPlayer.joins(:user).where(users: { is_guest: false }).where.not(damage_dealt: nil)
  end

  def community_damage_dealt
    community_base.average(:damage_dealt)&.round(0)&.to_i
  end

  def community_damage_received
    community_base.average(:damage_received)&.round(0)&.to_i
  end

  def top_suits
    grouped = Hash.new { |hash, key| hash[key] = { mobile_suit: nil, total: 0, wins: 0 } }
    filtered_matches.each do |match_player|
      entry = grouped[match_player.mobile_suit_id]
      entry[:mobile_suit] = match_player.mobile_suit
      entry[:total] += 1
      entry[:wins] += 1 if match_player.won?
    end
    grouped.values.map do |entry|
      { mobile_suit: entry[:mobile_suit], total: entry[:total], win_rate: percentage(entry[:wins], entry[:total]) }
    end.sort_by { |entry| -entry[:total] }.take(10)
  end

  def best_partners
    grouped = Hash.new { |hash, key| hash[key] = { user: nil, total: 0, wins: 0 } }
    filtered_matches.each do |match_player|
      partner = match_player.partner
      next unless partner

      entry = grouped[partner.user_id]
      entry[:user] = partner.user
      entry[:total] += 1
      entry[:wins] += 1 if match_player.won?
    end
    grouped.values.select { |entry| entry[:total] >= 3 }.map do |entry|
      { user: entry[:user], total: entry[:total], wins: entry[:wins], win_rate: percentage(entry[:wins], entry[:total]) }
    end.sort_by { |entry| [ -entry[:win_rate], -entry[:total] ] }.take(5)
  end

  def matchups_base
    @matchups_base ||= begin
      grouped = Hash.new { |hash, key| hash[key] = { mobile_suit: nil, total: 0, wins: 0 } }
      filtered_matches.each do |match_player|
        won = match_player.won?
        match_player.opponents.each do |opponent|
          next unless opponent.mobile_suit

          entry = grouped[opponent.mobile_suit_id]
          entry[:mobile_suit] = opponent.mobile_suit
          entry[:total] += 1
          entry[:wins] += 1 if won
        end
      end
      grouped.values.select { |entry| entry[:total] >= MATCHUP_MIN_GAMES }.map do |entry|
        { mobile_suit: entry[:mobile_suit], total: entry[:total], wins: entry[:wins], win_rate: percentage(entry[:wins], entry[:total]) }
      end
    end
  end

  def matchup_strong
    matchups_base.select { |entry| entry[:win_rate] >= 50 }.sort_by { |entry| [ -entry[:win_rate], -entry[:total] ] }.take(6)
  end

  def matchup_weak
    matchups_base.select { |entry| entry[:win_rate] < 50 }.sort_by { |entry| [ entry[:win_rate], -entry[:total] ] }.take(6)
  end

  def best_records
    return [] if stats_matches.empty?

    records = []
    if (match_player = max_by_field(:damage_dealt))
      records << record_entry("最多与ダメージ", match_player.damage_dealt, match_player, :number)
    end
    if (match_player = max_by_field(:exburst_damage)) && match_player.exburst_damage.to_i.positive?
      records << record_entry("最多EXバーストダメージ", match_player.exburst_damage, match_player, :number)
    end
    win_matches = stats_matches.select { |match_player| match_player.won? && match_player.damage_received.present? }
    if (match_player = win_matches.min_by { |mp| mp.damage_received.to_i })
      records << record_entry("最少被ダメージ（勝利）", match_player.damage_received, match_player, :number)
    end
    survivors = stats_matches.select { |match_player| (match_player.survival_times || []).any? }
    if (match_player = survivors.max_by { |mp| mp.survival_times.first.to_i })
      records << record_entry("最長 1機目 生存", match_player.survival_times.first, match_player, :survival)
    end
    records
  end

  def max_by_field(field)
    candidates = stats_matches.select { |match_player| match_player.public_send(field).present? }
    candidates.max_by { |match_player| match_player.public_send(field).to_i }
  end

  def record_entry(label, value, match_player, kind)
    {
      label: label,
      value: value,
      kind: kind,
      sub: "#{match_player.mobile_suit&.name} ・ #{match_player.match.event.name}"
    }
  end

  def max_winning_streak_data
    @max_winning_streak_data ||= begin
      max_streak = 0
      max_event = nil
      current_streak = 0

      ordered_match_players.each do |match_player|
        if match_player.won?
          current_streak += 1
          if current_streak > max_streak
            max_streak = current_streak
            max_event = match_player.match.event
          end
        else
          current_streak = 0
        end
      end

      { count: max_streak, event: max_event }
    end
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

  def cost_solo_stats
    data = Hash.new { |hash, key| hash[key] = { wins: 0, total: 0 } }
    filtered_matches.each do |match_player|
      entry = data[match_player.mobile_suit.cost]
      entry[:total] += 1
      entry[:wins] += 1 if match_player.won?
    end
    total_plays = data.values.sum { |entry| entry[:total] }

    [ 3000, 2500, 2000, 1500 ].map do |cost|
      entry = data[cost]
      {
        cost: cost,
        usage_count: entry[:total],
        usage_rate: percentage(entry[:total], total_plays),
        wins: entry[:wins],
        win_rate: percentage(entry[:wins], entry[:total])
      }
    end
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
