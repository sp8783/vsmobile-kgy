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
