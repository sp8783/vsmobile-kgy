class StatisticsPerformanceSurvivalTimeSnapshot
  def initialize(context:)
    @context = context
  end

  def to_h
    result = {
      survival_time_stats: context.survival_time_stats(context.stats_match_players, community_scope: :all),
      survival_time_stats_wins: context.survival_time_stats(context.win_match_players, community_scope: :wins),
      survival_time_stats_losses: context.survival_time_stats(context.loss_match_players, community_scope: :losses)
    }

    # コスト/機体で絞っている時のみ、自分の全試合・同コスト帯の生存時間も用意（比較対象スイッチ用）
    if context.filter_mobile_suits.any? || context.filter_costs.any?
      overall = context.all_user_stats_match_players
      result[:survival_user_overall] = context.user_survival_died_by_life(overall)

      same_cost = overall.select { |match_player| context.same_costs.include?(match_player.mobile_suit.cost) }
      unless same_cost.size == context.stats_match_players.size
        result[:survival_user_same_cost] = context.user_survival_died_by_life(same_cost)
      end
    end

    result
  end

  private

  attr_reader :context
end
