class StatisticsHighlightsSnapshot
  def initialize(filter_events:)
    @filter_events = filter_events
  end

  def to_h
    intense_match = intense_match_snapshot
    survival_highlights = survival_highlights_snapshot

    {
      highlight_most_damage: stats_match_players.order(damage_dealt: :desc).first,
      highlight_most_exburst_damage: base_match_players.where.not(exburst_damage: nil).order(exburst_damage: :desc).first,
      highlight_min_damage_received: min_damage_received_match_player,
      highlight_top_score: base_match_players.where.not(score: nil).order(score: :desc).first,
      highlight_most_intense_total: intense_match[:total],
      highlight_most_intense_match: intense_match[:match],
      highlight_longest_first_life: survival_highlights[:longest_first_life],
      highlight_longest_first_life_cs: survival_highlights[:longest_first_life_cs],
      highlight_shortest_first_life: survival_highlights[:shortest_first_life],
      highlight_shortest_first_life_cs: survival_highlights[:shortest_first_life_cs],
      highlight_longest_match: longest_timeline&.match,
      highlight_longest_match_cs: longest_timeline&.game_end_cs,
      highlight_shortest_match: shortest_timeline&.match,
      highlight_shortest_match_cs: shortest_timeline&.game_end_cs
    }
  end

  private

  attr_reader :filter_events

  def base_match_players
    @base_match_players ||= begin
      scope = MatchPlayer.joins(:match, :mobile_suit, :user)
                         .includes(:match, :mobile_suit, :user, match: :event)
      filter_by_events(scope)
    end
  end

  def stats_match_players
    @stats_match_players ||= base_match_players.where.not(damage_dealt: nil)
  end

  def min_damage_received_match_player
    scope = MatchPlayer.joins(:match, :mobile_suit, :user)
                       .includes(:match, :mobile_suit, :user, match: :event)
                       .where.not(damage_received: nil)
                       .where("matches.winning_team = match_players.team_number")

    filter_by_events(scope).order(damage_received: :asc).first
  end

  def intense_match_snapshot
    @intense_match_snapshot ||= begin
      scope = MatchPlayer.joins(:match).includes(match: :event).where.not(damage_dealt: nil)
      best_match = filter_by_events(scope).to_a
                                    .group_by(&:match_id)
                                    .filter_map do |_, match_players|
        next if match_players.any? { |match_player| match_player.damage_dealt.nil? }

        [ match_players.sum(&:damage_dealt), match_players.first.match ]
      end
                                    .max_by { |total, _| total }

      {
        total: best_match&.first,
        match: best_match&.last
      }
    end
  end

  def survival_highlights_snapshot
    longest_match_player = loaded_survival_match_players.max_by { |match_player| first_life_value(match_player) }

    died_on_first = loaded_survival_match_players.select do |match_player|
      survival_times = match_player.survival_times || []
      survival_times.size >= 2 || match_player.deaths.to_i >= 1
    end
    shortest_match_player = died_on_first.min_by { |match_player| first_life_value(match_player) }

    {
      longest_first_life: longest_match_player,
      longest_first_life_cs: longest_match_player ? first_life_value(longest_match_player) : nil,
      shortest_first_life: shortest_match_player,
      shortest_first_life_cs: shortest_match_player ? first_life_value(shortest_match_player) : nil
    }
  end

  def loaded_survival_match_players
    @loaded_survival_match_players ||= begin
      scope = base_match_players.where("survival_times IS NOT NULL AND jsonb_array_length(survival_times) > 0")
      scope.to_a
    end
  end

  def longest_timeline
    @longest_timeline ||= filtered_timelines.order(game_end_cs: :desc).first
  end

  def shortest_timeline
    @shortest_timeline ||= filtered_timelines.order(game_end_cs: :asc).first
  end

  def filtered_timelines
    @filtered_timelines ||= begin
      scope = MatchTimeline.joins(:match).includes(match: :event).where.not(game_end_cs: nil)
      filter_by_events(scope)
    end
  end

  def first_life_value(match_player)
    (match_player.survival_times || [])[0].to_i
  end

  def filter_by_events(scope)
    filter_events.any? ? scope.where(matches: { event_id: filter_events }) : scope
  end
end
