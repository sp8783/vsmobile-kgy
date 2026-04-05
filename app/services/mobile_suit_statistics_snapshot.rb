class MobileSuitStatisticsSnapshot
  def initialize(mobile_suit:)
    @mobile_suit = mobile_suit
  end

  def to_h
    {
      total_uses: total_uses,
      win_rate: win_rate,
      dominance: dominance,
      total_suits: all_suit_ids.size,
      rank_uses: rank_uses,
      rank_dominance: rank_dominance,
      rank_win_rate: rank_win_rate,
      total_suits_with_uses: win_rates_for_rank.size,
      player_ranking: player_ranking,
      partner_suits: partner_suits,
      partner_costs: partner_costs,
      global_perf: global_perf,
      player_perf: player_perf
    }
  end

  private

  attr_reader :mobile_suit

  def suit_match_players
    @suit_match_players ||= MatchPlayer.where(mobile_suit_id: mobile_suit.id)
                                       .joins(:match)
                                       .includes(:user, match: { match_players: :mobile_suit })
                                       .to_a
  end

  def total_uses
    @total_uses ||= suit_match_players.size
  end

  def wins
    @wins ||= suit_match_players.count(&:won?)
  end

  def win_rate
    @win_rate ||= percentage(wins, total_uses)
  end

  def dominance
    @dominance ||= (win_rate * total_uses).round(1)
  end

  def all_suit_ids
    @all_suit_ids ||= MobileSuit.ids
  end

  def all_suit_counts
    @all_suit_counts ||= MatchPlayer.joins(:match).group(:mobile_suit_id).count
  end

  def all_suit_wins
    @all_suit_wins ||= MatchPlayer.joins(:match)
                                  .where("matches.winning_team = match_players.team_number")
                                  .group(:mobile_suit_id)
                                  .count
  end

  def counts_for_rank
    @counts_for_rank ||= all_suit_ids.index_with { |id| all_suit_counts[id] || 0 }
  end

  def dominance_for_rank
    @dominance_for_rank ||= all_suit_ids.index_with do |id|
      total = all_suit_counts[id] || 0
      wins_count = all_suit_wins[id] || 0
      (percentage(wins_count, total) * total).round(1)
    end
  end

  def win_rates_for_rank
    @win_rates_for_rank ||= all_suit_counts.each_with_object({}) do |(suit_id, total), result|
      wins_count = all_suit_wins[suit_id] || 0
      result[suit_id] = percentage(wins_count, total)
    end
  end

  def rank_uses
    value_rank(counts_for_rank, mobile_suit.id)
  end

  def rank_dominance
    value_rank(dominance_for_rank, mobile_suit.id)
  end

  def rank_win_rate
    value_rank(win_rates_for_rank, mobile_suit.id)
  end

  def player_ranking
    suit_match_players.group_by(&:user_id)
                     .map do |_, match_players|
      {
        user: match_players.first.user,
        uses: match_players.size,
        win_rate: percentage(match_players.count(&:won?), match_players.size)
      }
    end
                     .sort_by { |data| -data[:uses] }
                     .first(5)
  end

  def partner_suits
    partner_stats_by_suit.map do |_, data|
      total = data[:total]
      {
        mobile_suit: data[:mobile_suit],
        total: total,
        ratio: percentage(total, total_uses),
        win_rate: percentage(data[:wins], total)
      }
    end.sort_by { |data| -data[:total] }
  end

  def partner_costs
    partner_stats_by_cost.map do |cost, data|
      total = data[:total]
      {
        cost: cost,
        total: total,
        ratio: percentage(total, total_uses),
        win_rate: percentage(data[:wins], total)
      }
    end.sort_by { |data| -data[:total] }
  end

  def partner_stats_by_suit
    @partner_stats_by_suit ||= begin
      stats = Hash.new { |hash, key| hash[key] = { mobile_suit: nil, wins: 0, total: 0 } }

      suit_match_players.each do |match_player|
        partner = match_player.partner
        next unless partner

        stats[partner.mobile_suit_id][:mobile_suit] = partner.mobile_suit
        stats[partner.mobile_suit_id][:total] += 1
        stats[partner.mobile_suit_id][:wins] += 1 if match_player.won?
      end

      stats
    end
  end

  def partner_stats_by_cost
    @partner_stats_by_cost ||= begin
      stats = Hash.new { |hash, key| hash[key] = { wins: 0, total: 0 } }

      suit_match_players.each do |match_player|
        partner = match_player.partner
        next unless partner

        stats[partner.mobile_suit.cost][:total] += 1
        stats[partner.mobile_suit.cost][:wins] += 1 if match_player.won?
      end

      stats
    end
  end

  def stats_match_players
    @stats_match_players ||= suit_match_players.select(&:has_stats?)
  end

  def global_perf
    build_perf(stats_match_players)
  end

  def player_perf
    stats_match_players.group_by(&:user_id)
                       .filter_map do |_, match_players|
      build_perf(match_players)&.merge(user: match_players.first.user)
    end
                       .sort_by { |data| -data[:stats_count] }
  end

  def build_perf(match_players)
    return nil if match_players.empty?

    deaths_total = match_players.sum { |match_player| match_player.deaths.to_i }
    exburst_deaths_total = match_players.sum { |match_player| match_player.exburst_deaths.to_i }

    {
      stats_count: match_players.size,
      avg_score: average_stat(match_players, :score),
      avg_kills: average_stat(match_players, :kills),
      avg_deaths: average_stat(match_players, :deaths),
      avg_damage_dealt: average_stat(match_players, :damage_dealt),
      avg_damage_recv: average_stat(match_players, :damage_received),
      avg_exburst_count: average_stat(match_players, :exburst_count),
      avg_exburst_damage: average_stat(match_players, :exburst_damage),
      avg_exburst_deaths: average_stat(match_players, :exburst_deaths),
      exburst_death_ratio: deaths_total.positive? ? (exburst_deaths_total.to_f / deaths_total * 100).round(1) : nil,
      ol_rate: bool_rate(match_players, :ex_overlimit_activated),
      survival_stats: survival_stats(match_players)
    }
  end

  def average_stat(match_players, attribute)
    values = match_players.map(&attribute).compact
    values.any? ? (values.sum.to_f / values.size).round(1) : nil
  end

  def bool_rate(match_players, attribute)
    values = match_players.map(&attribute).compact
    return nil if values.empty?

    (values.count(&:itself) * 100.0 / values.size).round(1)
  end

  def survival_stats(match_players)
    match_players_with_survival = match_players.select { |match_player| (match_player.survival_times || []).any? }
    return [] if match_players_with_survival.empty?

    max_lives = match_players_with_survival.map { |match_player| match_player.survival_times.size }.max

    max_lives.times.map do |life_index|
      match_players_with_life = match_players_with_survival.select { |match_player| match_player.survival_times.size > life_index }
      survived, died = match_players_with_life.partition do |match_player|
        match_player.survival_times.size == life_index + 1 && match_player.survival_times.size > match_player.deaths.to_i
      end

      {
        life: life_index + 1,
        survived_cs: average_cs_value(survived, life_index),
        survived_count: survived.size,
        died_cs: average_cs_value(died, life_index),
        died_count: died.size
      }
    end
  end

  def average_cs_value(match_players, life_index)
    values = match_players.filter_map { |match_player| match_player.survival_times[life_index] }
    return nil if values.empty?

    (values.sum.to_f / values.size).round(0).to_i
  end

  def value_rank(values_by_id, target_id)
    target_value = values_by_id[target_id]
    return nil if target_value.nil?

    values_by_id.count { |_, value| value > target_value } + 1
  end

  def percentage(numerator, denominator)
    denominator.positive? ? (numerator.to_f / denominator * 100).round(1) : 0.0
  end
end
