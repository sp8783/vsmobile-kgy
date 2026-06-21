class StatisticsPerformanceSnapshotContext
  HAS_STATS_SQL = "score IS NOT NULL AND kills IS NOT NULL AND deaths IS NOT NULL AND " \
                  "damage_dealt IS NOT NULL AND damage_received IS NOT NULL AND exburst_damage IS NOT NULL"
  COMMUNITY_PERF_KEYS = %i[
    score
    kills
    deaths
    damage_dealt
    damage_received
    exburst_damage
    exburst_count
    first_unit_exburst_count
    later_unit_exburst_count
    exburst_deaths
    ol_rate
  ].freeze

  def initialize(user:, filtered_matches:, filter_events:, filter_mobile_suits:, filter_costs:)
    @user = user
    @filtered_matches = filtered_matches.to_a
    @filter_events = filter_events
    @filter_mobile_suits = filter_mobile_suits
    @filter_costs = filter_costs
  end

  attr_reader :user, :filtered_matches, :filter_events, :filter_mobile_suits, :filter_costs

  def stats_match_players
    @stats_match_players ||= filtered_matches.select(&:has_stats?)
  end

  def win_match_players
    @win_match_players ||= stats_match_players.select(&:won?)
  end

  def loss_match_players
    @loss_match_players ||= stats_match_players.reject(&:won?)
  end

  def all_loss_match_players
    @all_loss_match_players ||= filtered_matches.reject(&:won?)
  end

  def all_win_match_players
    @all_win_match_players ||= filtered_matches.select(&:won?)
  end

  def ex_remaining_on_loss
    @ex_remaining_on_loss ||= loss_match_players.count { |match_player| ex_remaining_on_loss?(match_player) }
  end

  def last_death_ex_on_loss
    @last_death_ex_on_loss ||= loss_match_players.count(&:last_death_ex_available)
  end

  def survive_loss_ex_on_loss
    @survive_loss_ex_on_loss ||= loss_match_players.count(&:survive_loss_ex_available)
  end

  def my_team_no_ol_losses
    @my_team_no_ol_losses ||= all_loss_match_players.count { |match_player| own_overlimit_flag(match_player) == true }
  end

  def opponent_no_ol_wins
    @opponent_no_ol_wins ||= all_win_match_players.count { |match_player| opponent_overlimit_flag(match_player) == true }
  end

  def has_overlimit_data?
    @has_overlimit_data ||= filtered_matches.any? { |match_player| !own_overlimit_flag(match_player).nil? }
  end

  def all_user_records
    @all_user_records ||= begin
      scope = MatchPlayer.where(user_id: user.id)
                         .joins(:match)
                         .includes(:match, :mobile_suit, :user, match: { rotation_match: :rotation })
      scope = scope.where(matches: { event_id: filter_events }) if filter_events.any?
      scope.to_a
    end
  end

  def all_user_stats_match_players
    @all_user_stats_match_players ||= all_user_records.select(&:has_stats?)
  end

  def same_costs
    @same_costs ||= if filter_mobile_suits.any?
      MobileSuit.where(id: filter_mobile_suits).pluck(:cost).uniq
    else
      filter_costs
    end
  end

  def same_cost_label
    @same_cost_label ||= "#{same_costs.sort.reverse.join('・')}コスト"
  end

  def community_exburst_loss_match_players
    @community_exburst_loss_match_players ||= community_base_scope
      .includes(:match)
      .where("matches.winning_team IS NOT NULL AND matches.winning_team != match_players.team_number")
      .where("last_death_ex_available IS NOT NULL OR survive_loss_ex_available IS NOT NULL")
      .to_a
  end

  def community_overlimit_match_players
    @community_overlimit_match_players ||= community_base_scope
      .includes(:match)
      .where("matches.winning_team IS NOT NULL")
      .to_a
  end

  def community_stats_match_players
    @community_stats_match_players ||= community_base_scope
      .includes(:match)
      .where(HAS_STATS_SQL)
      .to_a
  end

  def exburst_rate_snapshot(prefix:, match_players:)
    return {} if match_players.empty?

    {
      "#{prefix}_ex_remaining_rate".to_sym => percentage(match_players.count { |match_player| ex_remaining_on_loss?(match_player) }, match_players.size),
      "#{prefix}_last_death_ex_rate".to_sym => percentage(match_players.count(&:last_death_ex_available), match_players.size),
      "#{prefix}_survive_ex_rate".to_sym => percentage(match_players.count(&:survive_loss_ex_available), match_players.size)
    }
  end

  def overlimit_rate_snapshot(prefix:, loss_match_players:, win_match_players:)
    {}.tap do |snapshot|
      if loss_match_players.any?
        snapshot["#{prefix}_no_ol_loss_rate".to_sym] = percentage(loss_match_players.count { |match_player| own_overlimit_flag(match_player) == true }, loss_match_players.size)
      end

      if win_match_players.any?
        snapshot["#{prefix}_opp_no_ol_win_rate".to_sym] = percentage(win_match_players.count { |match_player| opponent_overlimit_flag(match_player) == true }, win_match_players.size)
      end
    end
  end

  def perf_stats(match_players)
    count = match_players.size
    return nil if count.zero?

    average_field = lambda do |field|
      valid_match_players = match_players.select { |match_player| match_player.public_send(field).present? }
      next nil if valid_match_players.empty?

      valid_match_players.sum { |match_player| match_player.public_send(field).to_f } / valid_match_players.size
    end

    {
      count: count,
      score: average_field.call(:score)&.round(1),
      kills: average_field.call(:kills)&.round(2),
      deaths: average_field.call(:deaths)&.round(2),
      damage_dealt: average_field.call(:damage_dealt)&.round(0),
      damage_received: average_field.call(:damage_received)&.round(0),
      exburst_damage: average_field.call(:exburst_damage)&.round(0),
      exburst_count: average_field.call(:exburst_count)&.round(2),
      first_unit_exburst_count: average_field.call(:first_unit_exburst_count)&.round(2),
      later_unit_exburst_count: later_unit_exburst_count(average_field),
      exburst_deaths: average_field.call(:exburst_deaths)&.round(2),
      exburst_death_rate: exburst_death_rate(match_players),
      ol_rate: percentage(match_players.count { |match_player| own_overlimit_flag(match_player) == false }, count)
    }
  end

  def community_user_perf_snapshot(match_players)
    count = match_players.size
    return nil if count.zero?

    sum_field = ->(field) { match_players.sum { |match_player| match_player.public_send(field).to_f } }
    total_exburst_count = match_players.sum { |match_player| match_player.exburst_count.to_i }
    total_exburst_deaths = match_players.sum { |match_player| match_player.exburst_deaths.to_i }

    {
      score: (sum_field.call(:score) / count).round(1),
      kills: (sum_field.call(:kills) / count).round(2),
      deaths: (sum_field.call(:deaths) / count).round(2),
      damage_dealt: (sum_field.call(:damage_dealt) / count).round(0),
      damage_received: (sum_field.call(:damage_received) / count).round(0),
      exburst_damage: (sum_field.call(:exburst_damage) / count).round(0),
      exburst_count: (sum_field.call(:exburst_count) / count).round(2),
      first_unit_exburst_count: (sum_field.call(:first_unit_exburst_count) / count).round(2),
      later_unit_exburst_count: [ (sum_field.call(:exburst_count) - sum_field.call(:first_unit_exburst_count)) / count, 0 ].max.round(2),
      exburst_deaths: (sum_field.call(:exburst_deaths) / count).round(2),
      exburst_death_rate: total_exburst_count.positive? ? percentage(total_exburst_deaths, total_exburst_count) : nil,
      ol_rate: percentage(match_players.count { |match_player| own_overlimit_flag(match_player) == false }, count)
    }
  end

  def merge_community_distribution!(snapshot, prefix, user_snapshots)
    return if user_snapshots.empty?

    snapshot["#{prefix}_avg".to_sym] = community_distribution_average(user_snapshots)
    snapshot["#{prefix}_min".to_sym] = community_distribution_extreme(user_snapshots, :min)
    snapshot["#{prefix}_max".to_sym] = community_distribution_extreme(user_snapshots, :max)
  end

  def survival_time_stats(user_match_players, community_scope:)
    user_survival_match_players = user_match_players.select { |match_player| match_player.survival_times.present? }
    return [] if user_survival_match_players.empty?

    community_match_players = community_survival_match_players(community_scope)
    max_lives = [ user_survival_match_players, community_match_players ].flat_map do |match_players|
      match_players.map { |match_player| (match_player.survival_times || []).size }
    end.max.to_i
    return [] if max_lives.zero?

    max_lives.times.map do |index|
      user_match_players_with_life = user_survival_match_players.select { |match_player| (match_player.survival_times || []).size > index }
      community_match_players_with_life = community_match_players.select { |match_player| (match_player.survival_times || []).size > index }

      user_survived_match_players, user_died_match_players = partition_survival(user_match_players_with_life, index)
      community_survived_match_players, community_died_match_players = partition_survival(community_match_players_with_life, index)

      {
        n: index + 1,
        died: survival_summary(user_died_match_players, community_died_match_players, index),
        survived: survival_summary(user_survived_match_players, community_survived_match_players, index)
      }
    end
  end

  # 自己比較用：指定 match_players の「撃墜された機体（died）」の平均生存cs を機体目ごとに返す
  def user_survival_died_by_life(match_players)
    survivors = match_players.select { |match_player| match_player.survival_times.present? }
    return [] if survivors.empty?

    max_lives = survivors.map { |match_player| match_player.survival_times.size }.max.to_i
    max_lives.times.map do |index|
      with_life = survivors.select { |match_player| match_player.survival_times.size > index }
      died = with_life.reject { |match_player| survived_life?(match_player, index) }
      values = died.filter_map { |match_player| match_player.survival_times[index] }
      values.any? ? average_value(values, precision: 0) : nil
    end
  end

  def own_overlimit_flag(match_player)
    match_player.team_number == 1 ? match_player.match.team1_ex_overlimit_before_end : match_player.match.team2_ex_overlimit_before_end
  end

  def opponent_overlimit_flag(match_player)
    match_player.team_number == 1 ? match_player.match.team2_ex_overlimit_before_end : match_player.match.team1_ex_overlimit_before_end
  end

  def average_value(values, precision:)
    return nil if values.empty?

    (values.sum.to_f / values.size).round(precision)
  end

  def percentage(numerator, denominator)
    denominator.positive? ? (numerator.to_f / denominator * 100).round(1) : 0.0
  end

  private

  def later_unit_exburst_count(average_field)
    exburst_count = average_field.call(:exburst_count)
    first_unit_exburst_count = average_field.call(:first_unit_exburst_count)
    return nil unless exburst_count && first_unit_exburst_count

    [ (exburst_count - first_unit_exburst_count).round(2), 0 ].max
  end

  def exburst_death_rate(match_players)
    total_exburst_count = match_players.sum { |match_player| match_player.exburst_count.to_i }
    return nil if total_exburst_count.zero?

    total_exburst_deaths = match_players.sum { |match_player| match_player.exburst_deaths.to_i }
    percentage(total_exburst_deaths, total_exburst_count)
  end

  def community_distribution_average(user_snapshots)
    valid_death_rates = user_snapshots.filter_map { |snapshot| snapshot[:exburst_death_rate] }

    {
      score: average_value(user_snapshots.map { |snapshot| snapshot[:score] }, precision: 1),
      kills: average_value(user_snapshots.map { |snapshot| snapshot[:kills] }, precision: 2),
      deaths: average_value(user_snapshots.map { |snapshot| snapshot[:deaths] }, precision: 2),
      damage_dealt: average_value(user_snapshots.map { |snapshot| snapshot[:damage_dealt] }, precision: 0),
      damage_received: average_value(user_snapshots.map { |snapshot| snapshot[:damage_received] }, precision: 0),
      exburst_damage: average_value(user_snapshots.map { |snapshot| snapshot[:exburst_damage] }, precision: 0),
      exburst_count: average_value(user_snapshots.map { |snapshot| snapshot[:exburst_count] }, precision: 2),
      first_unit_exburst_count: average_value(user_snapshots.map { |snapshot| snapshot[:first_unit_exburst_count] }, precision: 2),
      later_unit_exburst_count: average_value(user_snapshots.map { |snapshot| snapshot[:later_unit_exburst_count] }, precision: 2),
      exburst_deaths: average_value(user_snapshots.map { |snapshot| snapshot[:exburst_deaths] }, precision: 2),
      exburst_death_rate: valid_death_rates.any? ? average_value(valid_death_rates, precision: 1) : nil,
      ol_rate: average_value(user_snapshots.map { |snapshot| snapshot[:ol_rate] }, precision: 1)
    }
  end

  def community_distribution_extreme(user_snapshots, type)
    snapshot = COMMUNITY_PERF_KEYS.index_with do |key|
      values = user_snapshots.filter_map { |user_snapshot| user_snapshot[key] }
      values.public_send(type)
    end

    valid_death_rates = user_snapshots.filter_map { |user_snapshot| user_snapshot[:exburst_death_rate] }
    snapshot[:exburst_death_rate] = valid_death_rates.public_send(type) if valid_death_rates.any?
    snapshot
  end

  def community_base_scope
    @community_base_scope ||= begin
      scope = MatchPlayer.joins(:match, :user).where(users: { is_guest: false })
      scope = scope.where(matches: { event_id: filter_events }) if filter_events.any?
      scope
    end
  end

  def community_survival_match_players(community_scope)
    scope = community_base_scope.where("survival_times IS NOT NULL AND jsonb_array_length(survival_times) > 0")
    scope = case community_scope
    when :wins
      scope.where("matches.winning_team = match_players.team_number")
    when :losses
      scope.where("matches.winning_team != match_players.team_number")
    else
      scope
    end

    scope.to_a
  end

  def partition_survival(match_players, life_index)
    match_players.partition { |match_player| survived_life?(match_player, life_index) }
  end

  def survival_summary(user_match_players, community_match_players, life_index)
    user_values = user_match_players.filter_map { |match_player| match_player.survival_times[life_index] }
    community_averages = community_match_players.group_by(&:user_id).filter_map do |_, grouped_match_players|
      values = grouped_match_players.filter_map { |match_player| (match_player.survival_times || [])[life_index] }
      next if values.empty?

      average_value(values, precision: 0)
    end

    {
      user_count: user_match_players.size,
      user_avg_cs: user_values.any? ? average_value(user_values, precision: 0) : nil,
      community_avg_cs: community_averages.any? ? average_value(community_averages, precision: 0) : nil,
      community_min_cs: community_averages.min,
      community_max_cs: community_averages.max
    }
  end

  def survived_life?(match_player, life_index)
    survival_times = match_player.survival_times || []
    life_index == survival_times.size - 1 && survival_times.size > match_player.deaths.to_i
  end

  def ex_remaining_on_loss?(match_player)
    match_player.last_death_ex_available || match_player.survive_loss_ex_available
  end
end
