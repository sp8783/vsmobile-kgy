class StatisticsOverallSnapshot
  def initialize(filter_events:)
    @filter_events = filter_events
  end

  def to_h
    {
      overall_total_matches: base_matches.count,
      overall_total_players: base_match_players.map(&:user_id).uniq.size,
      overall_total_events: overall_total_events,
      popular_suits: popular_suits,
      high_winrate_suits: high_winrate_suits,
      cost_stats: cost_stats,
      dominant_suits: dominant_suits,
      event_stats: event_stats
    }
  end

  private

  attr_reader :filter_events

  def base_matches
    @base_matches ||= filter_events.any? ? Match.where(event_id: filter_events) : Match.all
  end

  def scoped_match_players
    @scoped_match_players ||= begin
      scope = MatchPlayer.joins(:match).includes(:match, :mobile_suit)
      filter_events.any? ? scope.where(matches: { event_id: filter_events }) : scope
    end
  end

  def base_match_players
    @base_match_players ||= scoped_match_players.to_a
  end

  def overall_total_events
    filter_events.any? ? filter_events.size : Event.joins(:matches).distinct.count
  end

  def popular_suits
    suit_usage_counts.sort_by { |_, count| -count }.first(10).map do |suit_id, count|
      {
        mobile_suit: mobile_suits_by_id[suit_id],
        usage_count: count,
        usage_rate: usage_denominator.positive? ? (count.to_f / usage_denominator * 100).round(1) : 0
      }
    end
  end

  def high_winrate_suits
    suit_stats_by_id
      .select { |_, stats| stats[:total] >= 5 }
      .map do |suit_id, stats|
        {
          mobile_suit: mobile_suits_by_id[suit_id],
          wins: stats[:wins],
          total: stats[:total],
          win_rate: percentage(stats[:wins], stats[:total])
        }
      end
      .sort_by { |entry| -entry[:win_rate] }
      .first(10)
  end

  def cost_stats
    total_usage = cost_stats_by_cost.values.sum { |entry| entry[:total] }

    cost_stats_by_cost.sort_by { |cost, _| -cost }.map do |cost, entry|
      {
        cost: cost,
        usage_count: entry[:total],
        usage_rate: percentage(entry[:total], total_usage),
        wins: entry[:wins],
        win_rate: percentage(entry[:wins], entry[:total])
      }
    end
  end

  def dominant_suits
    suit_stats_by_id
      .map do |suit_id, stats|
        win_rate = percentage(stats[:wins], stats[:total])

        {
          mobile_suit: mobile_suits_by_id[suit_id],
          wins: stats[:wins],
          total: stats[:total],
          win_rate: win_rate,
          dominance: (win_rate * stats[:total]).round(1)
        }
      end
      .sort_by { |entry| -entry[:dominance] }
      .first(10)
  end

  def event_stats
    player_counts = player_counts_by_event

    events_with_match_counts.map do |event|
      {
        event: event,
        match_count: event.match_count,
        player_count: player_counts[event.id] || 0
      }
    end
  end

  def suit_usage_counts
    @suit_usage_counts ||= base_match_players.each_with_object(Hash.new(0)) do |match_player, counts|
      counts[match_player.mobile_suit_id] += 1
    end
  end

  def suit_stats_by_id
    @suit_stats_by_id ||= base_match_players.each_with_object(Hash.new { |hash, key| hash[key] = { wins: 0, total: 0 } }) do |match_player, stats|
      entry = stats[match_player.mobile_suit_id]
      entry[:total] += 1
      entry[:wins] += 1 if match_player.won?
    end
  end

  def cost_stats_by_cost
    @cost_stats_by_cost ||= base_match_players.each_with_object(Hash.new { |hash, key| hash[key] = { wins: 0, total: 0 } }) do |match_player, stats|
      entry = stats[match_player.mobile_suit.cost]
      entry[:total] += 1
      entry[:wins] += 1 if match_player.won?
    end
  end

  def mobile_suits_by_id
    @mobile_suits_by_id ||= MobileSuit.where(id: suit_usage_counts.keys).index_by(&:id)
  end

  def usage_denominator
    @usage_denominator ||= base_matches.count * 4
  end

  def events_with_match_counts
    @events_with_match_counts ||= begin
      scope = Event.joins(:matches)
                   .select("events.*, COUNT(DISTINCT matches.id) as match_count")
                   .group("events.id")
                   .order(held_on: :desc)
                   .limit(10)

      filter_events.any? ? scope.where(id: filter_events) : scope
    end
  end

  def player_counts_by_event
    event_ids = events_with_match_counts.map(&:id)
    return {} if event_ids.empty?

    MatchPlayer.joins(:match)
               .where(matches: { event_id: event_ids })
               .group("matches.event_id")
               .distinct
               .count(:user_id)
  end

  def percentage(numerator, denominator)
    denominator.positive? ? (numerator.to_f / denominator * 100).round(1) : 0
  end
end
