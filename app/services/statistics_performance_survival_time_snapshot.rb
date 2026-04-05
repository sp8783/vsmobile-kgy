class StatisticsPerformanceSurvivalTimeSnapshot
  def initialize(context:)
    @context = context
  end

  def to_h
    {
      survival_time_stats: context.survival_time_stats(context.stats_match_players, community_scope: :all),
      survival_time_stats_wins: context.survival_time_stats(context.win_match_players, community_scope: :wins),
      survival_time_stats_losses: context.survival_time_stats(context.loss_match_players, community_scope: :losses)
    }
  end

  private

  attr_reader :context
end
