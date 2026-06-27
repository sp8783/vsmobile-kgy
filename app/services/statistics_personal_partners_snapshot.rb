class StatisticsPersonalPartnersSnapshot < StatisticsPersonalTabSnapshotBase
  def to_h
    { partners_list: partners_list }
  end

  private

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
      entry[:suit_combinations][[ match_player.mobile_suit, partner.mobile_suit ]] += 1
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
end
