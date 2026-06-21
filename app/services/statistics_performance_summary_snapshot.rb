class StatisticsPerformanceSummarySnapshot
  def initialize(context:)
    @context = context
  end

  def to_h
    {
      stats_total: context.stats_match_players.size,
      stats_wins: context.win_match_players.size,
      stats_losses: context.loss_match_players.size,
      performance_overall: context.perf_stats(context.stats_match_players),
      performance_wins: context.perf_stats(context.win_match_players),
      performance_losses: context.perf_stats(context.loss_match_players),
      ex_remaining_on_loss: context.ex_remaining_on_loss,
      last_death_ex_on_loss: context.last_death_ex_on_loss,
      survive_loss_ex_on_loss: context.survive_loss_ex_on_loss,
      my_team_no_ol_losses: context.my_team_no_ol_losses,
      total_losses: context.all_loss_match_players.size,
      opponent_no_ol_wins: context.opponent_no_ol_wins,
      total_wins_all: context.all_win_match_players.size,
      has_ol_data: context.has_overlimit_data?
    }
  end

  private

  attr_reader :context
end
