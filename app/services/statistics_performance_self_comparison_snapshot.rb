class StatisticsPerformanceSelfComparisonSnapshot
  def initialize(context:)
    @context = context
  end

  def to_h
    return {} unless context.filter_mobile_suits.any? || context.filter_costs.any?

    snapshot = {
      user_overall_avg: context.perf_stats(context.all_user_stats_match_players),
      user_overall_wins: context.perf_stats(context.all_user_stats_match_players.select(&:won?)),
      user_overall_losses: context.perf_stats(context.all_user_stats_match_players.reject(&:won?))
    }

    snapshot.merge!(context.exburst_rate_snapshot(prefix: :user_overall, match_players: context.all_user_stats_match_players.reject(&:won?)))
    snapshot.merge!(context.overlimit_rate_snapshot(prefix: :user_overall, loss_match_players: context.all_user_records.reject(&:won?), win_match_players: context.all_user_records.select(&:won?)))

    same_cost_records = context.all_user_records.select { |match_player| context.same_costs.include?(match_player.mobile_suit.cost) }
    same_cost_stats_match_players = context.all_user_stats_match_players.select { |match_player| context.same_costs.include?(match_player.mobile_suit.cost) }
    return snapshot if same_cost_stats_match_players.size == context.stats_match_players.size

    snapshot.merge!(
      user_same_cost_avg: context.perf_stats(same_cost_stats_match_players),
      user_same_cost_wins: context.perf_stats(same_cost_stats_match_players.select(&:won?)),
      user_same_cost_losses: context.perf_stats(same_cost_stats_match_players.reject(&:won?)),
      same_cost_label: context.same_cost_label
    )
    snapshot.merge!(context.exburst_rate_snapshot(prefix: :user_same_cost, match_players: same_cost_stats_match_players.reject(&:won?)))
    snapshot.merge!(context.overlimit_rate_snapshot(prefix: :user_same_cost, loss_match_players: same_cost_records.reject(&:won?), win_match_players: same_cost_records.select(&:won?)))
    snapshot
  end

  private

  attr_reader :context
end
