class StatisticsPersonalEventProgressionSnapshot < StatisticsPersonalTabSnapshotBase
  def to_h
    { event_progression_list: event_progression_list }
  end

  private

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
end
