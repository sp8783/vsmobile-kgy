class StatisticsPerformanceCommunityExburstSnapshot
  def initialize(context:)
    @context = context
  end

  def to_h
    return {} if context.community_exburst_loss_match_players.empty?

    last_death_rates = []
    survive_rates = []
    ex_remaining_rates = context.community_exburst_loss_match_players.group_by(&:user_id).map do |_, match_players|
      count = match_players.size
      remaining_count = match_players.count { |match_player| ex_remaining_on_loss?(match_player) }
      last_death_rates << context.percentage(match_players.count(&:last_death_ex_available), count)
      survive_rates << context.percentage(match_players.count(&:survive_loss_ex_available), count)
      context.percentage(remaining_count, count)
    end

    {
      community_ex_remaining_rate: context.average_value(ex_remaining_rates, precision: 1),
      community_ex_remaining_min: ex_remaining_rates.min,
      community_ex_remaining_max: ex_remaining_rates.max,
      community_last_death_ex_rate: context.average_value(last_death_rates, precision: 1),
      community_last_death_ex_min: last_death_rates.min,
      community_last_death_ex_max: last_death_rates.max,
      community_survive_ex_rate: context.average_value(survive_rates, precision: 1),
      community_survive_ex_min: survive_rates.min,
      community_survive_ex_max: survive_rates.max
    }
  end

  private

  attr_reader :context

  def ex_remaining_on_loss?(match_player)
    match_player.last_death_ex_available || match_player.survive_loss_ex_available
  end
end
