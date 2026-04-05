class StatisticsPersonalTabSnapshot
  def initialize(tab:, filtered_matches:)
    @tab = tab
    @filtered_matches_relation = filtered_matches
    @filtered_matches = filtered_matches.to_a
  end

  def to_h
    case tab
    when "overview"
      overview_snapshot
    when "partners"
      { partners_list: partners_list }
    when "mobile_suits", "opponent_suits"
      {
        mobile_suits_list: mobile_suits_list,
        opponent_suits_list: opponent_suits_list
      }
    when "events"
      { events_list: events_list }
    when "opponents"
      { opponents_list: opponents_list }
    when "event_progression"
      { event_progression_list: event_progression_list }
    else
      {}
    end
  end

  private

  attr_reader :tab, :filtered_matches, :filtered_matches_relation

  def overview_snapshot
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
      cost_key = [ match_player.mobile_suit.cost, partner_cost ]
      entry = cost_data[cost_key]
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

  def partners_list
    partner_data = Hash.new do |hash, key|
      hash[key] = {
        user: nil,
        wins: 0,
        total: 0,
        suit_combinations: Hash.new(0),
        last_played_at: nil
      }
    end

    filtered_matches.each do |match_player|
      partner = match_player.partner
      next unless partner

      entry = partner_data[partner.user_id]
      entry[:user] = partner.user
      entry[:total] += 1
      entry[:wins] += 1 if match_player.won?
      entry[:suit_combinations]["#{match_player.mobile_suit.name} & #{partner.mobile_suit.name}"] += 1
      entry[:last_played_at] = latest_time(entry[:last_played_at], match_player.match.played_at)
    end

    partner_data.values.map do |entry|
      {
        user: entry[:user],
        wins: entry[:wins],
        total: entry[:total],
        win_rate: percentage(entry[:wins], entry[:total]),
        top_combinations: top_entries(entry[:suit_combinations]),
        last_played_at: entry[:last_played_at]
      }
    end.sort_by { |entry| -entry[:win_rate] }
  end

  def mobile_suits_list
    mobile_suit_aggregates[:suits].values.map do |entry|
      stats = entry[:stats_mps]
      avg_kills = average(stats, :kills)
      avg_deaths = average(stats, :deaths)

      {
        mobile_suit: entry[:mobile_suit],
        wins: entry[:wins],
        total: entry[:total],
        win_rate: percentage(entry[:wins], entry[:total]),
        top_partner_suits: top_entries(entry[:partner_suits]),
        last_used_at: entry[:last_used_at],
        avg_score: average(stats, :score)&.round(1),
        kd_ratio: kd_ratio(avg_kills, avg_deaths)
      }
    end.sort_by { |entry| -entry[:total] }
  end

  def opponent_suits_list
    mobile_suit_aggregates[:opponent_suits].values.map do |entry|
      {
        mobile_suit: entry[:mobile_suit],
        wins: entry[:wins],
        total: entry[:total],
        win_rate: percentage(entry[:wins], entry[:total]),
        last_faced_at: entry[:last_faced_at]
      }
    end.sort_by { |entry| -entry[:total] }
  end

  def events_list
    event_data = Hash.new do |hash, key|
      hash[key] = {
        event: nil,
        wins: 0,
        total: 0,
        suits_used: Hash.new(0),
        partners: Hash.new(0)
      }
    end

    filtered_matches.each do |match_player|
      event = match_player.match.event
      entry = event_data[event.id]
      entry[:event] = event
      entry[:total] += 1
      entry[:wins] += 1 if match_player.won?
      entry[:suits_used][match_player.mobile_suit.name] += 1

      partner = match_player.partner
      entry[:partners][partner.user.nickname] += 1 if partner
    end

    event_data.values.map do |entry|
      {
        event: entry[:event],
        wins: entry[:wins],
        total: entry[:total],
        win_rate: percentage(entry[:wins], entry[:total]),
        top_suits: top_entries(entry[:suits_used]),
        top_partners: top_entries(entry[:partners])
      }
    end.sort_by { |entry| entry[:event].held_on }.reverse
  end

  def opponents_list
    opponent_data = Hash.new do |hash, key|
      hash[key] = {
        user: nil,
        wins: 0,
        total: 0,
        suits_used: Hash.new(0),
        last_played_at: nil
      }
    end

    filtered_matches.each do |match_player|
      match_player.opponents.each do |opponent|
        entry = opponent_data[opponent.user_id]
        entry[:user] = opponent.user
        entry[:total] += 1
        entry[:wins] += 1 if match_player.won?
        entry[:suits_used][opponent.mobile_suit.name] += 1
        entry[:last_played_at] = latest_time(entry[:last_played_at], match_player.match.played_at)
      end
    end

    opponent_data.values.map do |entry|
      {
        user: entry[:user],
        wins: entry[:wins],
        total: entry[:total],
        win_rate: percentage(entry[:wins], entry[:total]),
        top_suits: top_entries(entry[:suits_used]),
        last_played_at: entry[:last_played_at]
      }
    end.sort_by { |entry| -entry[:total] }
  end

  def event_progression_list
    progression_data = Hash.new do |hash, key|
      hash[key] = {
        event: nil,
        has_rotation: false,
        rotations: Hash.new { |rotations, rotation_id| rotations[rotation_id] = { wins: 0, total: 0, rotation_name: nil, matches: [] } },
        all_matches: []
      }
    end

    filtered_matches.each do |match_player|
      match = match_player.match
      event_entry = progression_data[match.event_id]
      event_entry[:event] = match.event
      event_entry[:all_matches] << match_player

      rotation = match.rotation_match&.rotation
      next unless rotation

      event_entry[:has_rotation] = true
      rotation_entry = event_entry[:rotations][rotation.id]
      rotation_entry[:rotation_name] = "#{rotation.round_number}周目"
      rotation_entry[:total] += 1
      rotation_entry[:wins] += 1 if match_player.won?
      rotation_entry[:matches] << match_player
    end

    progression_data.values.map do |entry|
      all_matches = entry[:all_matches]
      total_matches = all_matches.size
      total_wins = all_matches.count(&:won?)

      {
        event: entry[:event],
        has_rotation: entry[:has_rotation],
        rotation_stats: rotation_stats_for(entry),
        term_stats: term_stats_for(all_matches),
        total_matches: total_matches,
        overall_win_rate: percentage(total_wins, total_matches)
      }
    end.select { |entry| entry[:term_stats].any? || entry[:rotation_stats].any? }
      .sort_by { |entry| entry[:event].held_on }
      .reverse
  end

  def ordered_match_players
    @ordered_match_players ||= if filtered_matches_relation.respond_to?(:order)
      filtered_matches_relation.order("matches.played_at ASC").to_a
    else
      filtered_matches.sort_by { |match_player| [ match_sort_time(match_player), match_player.match.id ] }
    end
  end

  def mobile_suit_aggregates
    @mobile_suit_aggregates ||= begin
      suit_data = Hash.new do |hash, key|
        hash[key] = {
          mobile_suit: nil,
          wins: 0,
          total: 0,
          partner_suits: Hash.new(0),
          last_used_at: nil,
          stats_mps: []
        }
      end

      opponent_suit_data = Hash.new do |hash, key|
        hash[key] = {
          mobile_suit: nil,
          wins: 0,
          total: 0,
          last_faced_at: nil
        }
      end

      filtered_matches.each do |match_player|
        suit_entry = suit_data[match_player.mobile_suit_id]
        suit_entry[:mobile_suit] = match_player.mobile_suit
        suit_entry[:total] += 1
        suit_entry[:wins] += 1 if match_player.won?
        suit_entry[:stats_mps] << match_player if match_player.has_stats?
        suit_entry[:last_used_at] = latest_time(suit_entry[:last_used_at], match_player.match.played_at)

        partner = match_player.partner
        suit_entry[:partner_suits][partner.mobile_suit.name] += 1 if partner

        match_player.opponents.each do |opponent|
          opponent_entry = opponent_suit_data[opponent.mobile_suit_id]
          opponent_entry[:mobile_suit] = opponent.mobile_suit
          opponent_entry[:total] += 1
          opponent_entry[:wins] += 1 if match_player.won?
          opponent_entry[:last_faced_at] = latest_time(opponent_entry[:last_faced_at], match_player.match.played_at)
        end
      end

      {
        suits: suit_data,
        opponent_suits: opponent_suit_data
      }
    end
  end

  def rotation_stats_for(event_entry)
    return [] unless event_entry[:has_rotation]

    event_entry[:rotations].map do |rotation_id, rotation_entry|
      {
        rotation_id: rotation_id,
        rotation_name: rotation_entry[:rotation_name],
        wins: rotation_entry[:wins],
        total: rotation_entry[:total],
        losses: rotation_entry[:total] - rotation_entry[:wins],
        win_rate: percentage(rotation_entry[:wins], rotation_entry[:total])
      }
    end
  end

  def term_stats_for(match_players)
    sorted_match_players = match_players.sort_by { |match_player| match_player.match.played_at }
    return [] if sorted_match_players.empty?

    match_count = sorted_match_players.size

    (1..8).filter_map do |index|
      start_index = ((index - 1) * match_count / 8.0).round
      end_index = (index * match_count / 8.0).round
      slice = sorted_match_players[start_index...end_index]
      next if slice.blank?

      wins = slice.count(&:won?)
      total = slice.size

      {
        rotation_name: "第#{index}ターム",
        wins: wins,
        total: total,
        losses: total - wins,
        win_rate: percentage(wins, total)
      }
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

  def match_sort_time(match_player)
    match_player.match.played_at || Time.zone.at(0)
  end

  def percentage(numerator, denominator)
    denominator.positive? ? (numerator.to_f / denominator * 100).round(1) : 0
  end
end
