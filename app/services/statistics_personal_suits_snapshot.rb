class StatisticsPersonalSuitsSnapshot < StatisticsPersonalTabSnapshotBase
  def to_h
    {
      mobile_suits_list: mobile_suits_list,
      opponent_suits_list: opponent_suits_list
    }
  end

  private

  def mobile_suits_list
    mobile_suit_aggregates[:suits].values.map do |entry|
      stats = entry[:stats_mps]

      {
        mobile_suit: entry[:mobile_suit],
        wins: entry[:wins],
        total: entry[:total],
        win_rate: percentage(entry[:wins], entry[:total]),
        top_partner_suits: top_entries(entry[:partner_suits]),
        last_used_at: entry[:last_used_at],
        avg_damage_dealt: average(stats, :damage_dealt)&.round,
        avg_damage_received: average(stats, :damage_received)&.round,
        avg_exburst_damage: average(stats, :exburst_damage)&.round,
        avg_exburst_count: average(stats, :exburst_count)&.round(2),
        ol_rate: overlimit_rate(stats),
        first_life_cs: first_life_avg(stats)
      }
    end.sort_by { |entry| -entry[:total] }
  end

  def overlimit_rate(stats)
    valid = stats.reject { |match_player| own_overlimit_flag(match_player).nil? }
    return nil if valid.empty?

    percentage(valid.count { |match_player| own_overlimit_flag(match_player) == false }, valid.size)
  end

  def own_overlimit_flag(match_player)
    match_player.team_number == 1 ? match_player.match.team1_ex_overlimit_before_end : match_player.match.team2_ex_overlimit_before_end
  end

  def first_life_avg(stats)
    values = stats.filter_map { |match_player| match_player.survival_times&.first }
    values.any? ? (values.sum.to_f / values.size).round : nil
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
end
