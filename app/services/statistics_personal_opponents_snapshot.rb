class StatisticsPersonalOpponentsSnapshot < StatisticsPersonalTabSnapshotBase
  def to_h
    { opponents_list: opponents_list }
  end

  private

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
end
