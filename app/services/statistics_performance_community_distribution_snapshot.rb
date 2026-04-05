class StatisticsPerformanceCommunityDistributionSnapshot
  def initialize(context:)
    @context = context
  end

  def to_h
    return {} if context.community_stats_match_players.empty?

    user_perf_snapshots = []
    user_win_snapshots = []
    user_loss_snapshots = []

    context.community_stats_match_players.group_by(&:user_id).each_value do |match_players|
      overall_snapshot = context.community_user_perf_snapshot(match_players)
      win_snapshot = context.community_user_perf_snapshot(match_players.select(&:won?))
      loss_snapshot = context.community_user_perf_snapshot(match_players.reject(&:won?).select { |match_player| match_player.match.winning_team.present? })

      user_perf_snapshots << overall_snapshot if overall_snapshot
      user_win_snapshots << win_snapshot if win_snapshot
      user_loss_snapshots << loss_snapshot if loss_snapshot
    end

    {}.tap do |snapshot|
      context.merge_community_distribution!(snapshot, "community", user_perf_snapshots)
      context.merge_community_distribution!(snapshot, "community_wins", user_win_snapshots)
      context.merge_community_distribution!(snapshot, "community_losses", user_loss_snapshots)
    end
  end

  private

  attr_reader :context
end
