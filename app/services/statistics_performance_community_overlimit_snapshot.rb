class StatisticsPerformanceCommunityOverlimitSnapshot
  def initialize(context:)
    @context = context
  end

  def to_h
    return {} if context.community_overlimit_match_players.empty?

    no_ol_loss_rates = []
    opponent_no_ol_win_rates = []

    context.community_overlimit_match_players.group_by(&:user_id).each_value do |match_players|
      loss_match_players = match_players.reject(&:won?)
      if loss_match_players.any?
        no_ol_loss_rates << context.percentage(loss_match_players.count { |match_player| context.own_overlimit_flag(match_player) == true }, loss_match_players.size)
      end

      win_match_players = match_players.select(&:won?)
      if win_match_players.any?
        opponent_no_ol_win_rates << context.percentage(win_match_players.count { |match_player| context.opponent_overlimit_flag(match_player) == true }, win_match_players.size)
      end
    end

    {}.tap do |snapshot|
      if no_ol_loss_rates.any?
        snapshot.merge!(
          community_no_ol_loss_rate: context.average_value(no_ol_loss_rates, precision: 1),
          community_no_ol_loss_min: no_ol_loss_rates.min,
          community_no_ol_loss_max: no_ol_loss_rates.max
        )
      end

      if opponent_no_ol_win_rates.any?
        snapshot.merge!(
          community_opp_no_ol_win_rate: context.average_value(opponent_no_ol_win_rates, precision: 1),
          community_opp_no_ol_win_min: opponent_no_ol_win_rates.min,
          community_opp_no_ol_win_max: opponent_no_ol_win_rates.max
        )
      end
    end
  end

  private

  attr_reader :context
end
