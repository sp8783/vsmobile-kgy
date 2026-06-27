class StatisticsPersonalEventsSnapshot < StatisticsPersonalTabSnapshotBase
  def to_h
    { events_list: events_list }
  end

  private

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
      entry[:suits_used][match_player.mobile_suit] += 1

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
end
