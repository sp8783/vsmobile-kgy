class MobileSuitsController < ApplicationController
  before_action :authenticate_user!

  COSTS = [ 3000, 2500, 2000, 1500 ].freeze

  def index
    @counts_by_cost = MobileSuit.group(:cost).count
    @selected_cost = params[:cost].to_i.in?(COSTS) ? params[:cost].to_i : nil
    @suits = @selected_cost ? MobileSuit.where(cost: @selected_cost).order(:position) : MobileSuit.all.order(:position)
    @search_query = params[:q].to_s.strip
  end

  def show
    @suit = MobileSuit.find(params[:id])
    calculate_global_stats
  end

  private

  def calculate_global_stats
    suit_mps = MatchPlayer.where(mobile_suit_id: @suit.id)
                          .joins(:match)
                          .includes(:user, match: { match_players: :mobile_suit })

    @total_uses = suit_mps.count
    wins        = suit_mps.count { |mp| mp.match.winning_team == mp.team_number }
    @win_rate   = @total_uses > 0 ? (wins.to_f / @total_uses * 100).round(1) : 0.0
    @dominance  = (@win_rate * @total_uses).round(1)

    # ランキング用: SQLで全機体の使用回数・勝利数を一括取得
    all_suit_counts = MatchPlayer.joins(:match).group(:mobile_suit_id).count
    all_suit_wins   = MatchPlayer.joins(:match)
                                 .where("matches.winning_team = match_players.team_number")
                                 .group(:mobile_suit_id)
                                 .count

    all_ids      = MobileSuit.pluck(:id)
    @total_suits = all_ids.size  # 全登録機体数（未使用含む）

    # 使用回数ランキング: 全機体対象（未使用 = 0）
    counts_for_rank = all_ids.index_with { |id| all_suit_counts[id] || 0 }
    @rank_uses = value_rank(counts_for_rank, @suit.id, :desc)

    # 環境支配度ランキング: 全機体対象（未使用 = 0）
    dominance_for_rank = all_ids.index_with do |id|
      total  = all_suit_counts[id] || 0
      wins_n = all_suit_wins[id] || 0
      wr     = total > 0 ? (wins_n.to_f / total * 100) : 0.0
      (wr * total).round(1)
    end
    @rank_dominance = value_rank(dominance_for_rank, @suit.id, :desc)

    # 勝率ランキング: 使用実績のある機体のみ対象（未使用機体を含めると不公平なため）
    win_rates_for_rank = all_suit_counts.each_with_object({}) do |(sid, total), h|
      wins_n = all_suit_wins[sid] || 0
      h[sid] = (wins_n.to_f / total * 100).round(1)
    end
    @rank_win_rate        = value_rank(win_rates_for_rank, @suit.id, :desc)
    @total_suits_with_uses = win_rates_for_rank.size

    # プレイヤーランキング TOP5
    @player_ranking = suit_mps.group_by(&:user_id).map do |_, mps|
      wins_n  = mps.count { |mp| mp.match.winning_team == mp.team_number }
      total_n = mps.count
      {
        user:     mps.first.user,
        uses:     total_n,
        win_rate: total_n > 0 ? (wins_n.to_f / total_n * 100).round(1) : 0.0
      }
    end.sort_by { |d| -d[:uses] }.first(5)

    # 相方機体別分析
    partner_suit_data = Hash.new { |h, k| h[k] = { mobile_suit: nil, wins: 0, total: 0 } }
    suit_mps.each do |my_mp|
      partner_mp = my_mp.match.match_players.find do |mp|
        mp.team_number == my_mp.team_number && mp.mobile_suit_id != @suit.id
      end
      next unless partner_mp

      pid = partner_mp.mobile_suit_id
      partner_suit_data[pid][:mobile_suit] = partner_mp.mobile_suit
      partner_suit_data[pid][:total] += 1
      partner_suit_data[pid][:wins] += 1 if my_mp.match.winning_team == my_mp.team_number
    end

    @partner_suits = partner_suit_data.map do |_, d|
      total = d[:total]
      {
        mobile_suit: d[:mobile_suit],
        total:       total,
        ratio:       @total_uses > 0 ? (total.to_f / @total_uses * 100).round(1) : 0.0,
        win_rate:    total > 0 ? (d[:wins].to_f / total * 100).round(1) : 0.0
      }
    end.sort_by { |d| -d[:total] }

    # 相方コスト別分析
    partner_cost_data = Hash.new { |h, k| h[k] = { wins: 0, total: 0 } }
    suit_mps.each do |my_mp|
      partner_mp = my_mp.match.match_players.find do |mp|
        mp.team_number == my_mp.team_number && mp.mobile_suit_id != @suit.id
      end
      next unless partner_mp

      cost = partner_mp.mobile_suit.cost
      partner_cost_data[cost][:total] += 1
      partner_cost_data[cost][:wins] += 1 if my_mp.match.winning_team == my_mp.team_number
    end

    @partner_costs = partner_cost_data.map do |cost, d|
      total = d[:total]
      {
        cost:     cost,
        total:    total,
        ratio:    @total_uses > 0 ? (total.to_f / @total_uses * 100).round(1) : 0.0,
        win_rate: total > 0 ? (d[:wins].to_f / total * 100).round(1) : 0.0
      }
    end.sort_by { |d| -d[:total] }

    # パフォーマンス統計（has_stats? の試合のみ）
    stats_mps   = suit_mps.select(&:has_stats?)
    @global_perf = build_perf(stats_mps)

    # プレイヤー別パフォーマンス（stats持ち試合があるプレイヤーのみ）
    @player_perf = stats_mps.group_by(&:user_id).filter_map do |_, mps|
      build_perf(mps)&.merge(user: mps.first.user)
    end.sort_by { |d| -d[:stats_count] }
  end

  # 同率考慮ランキング: 自分より strict に上位の件数 + 1
  def value_rank(hash, target_id, direction)
    target_val = hash[target_id]
    return nil if target_val.nil?

    better_count = if direction == :desc
      hash.count { |_, v| v > target_val }
    else
      hash.count { |_, v| v < target_val }
    end
    better_count + 1
  end

  def build_perf(mps)
    return nil if mps.empty?

    deaths_total         = mps.sum { |mp| mp.deaths.to_i }
    exburst_deaths_total = mps.sum { |mp| mp.exburst_deaths.to_i }

    {
      stats_count:         mps.size,
      avg_score:           avg_stat(mps, :score),
      avg_kills:           avg_stat(mps, :kills),
      avg_deaths:          avg_stat(mps, :deaths),
      avg_damage_dealt:    avg_stat(mps, :damage_dealt),
      avg_damage_recv:     avg_stat(mps, :damage_received),
      avg_exburst_count:   avg_stat(mps, :exburst_count),
      avg_exburst_damage:  avg_stat(mps, :exburst_damage),
      avg_exburst_deaths:  avg_stat(mps, :exburst_deaths),
      exburst_death_ratio: deaths_total > 0 ? (exburst_deaths_total.to_f / deaths_total * 100).round(1) : nil,
      ol_rate:             bool_rate(mps, :ex_overlimit_activated),
      survival_stats:      calc_survival_stats(mps)
    }
  end

  def avg_stat(mps, attr)
    values = mps.map(&attr).compact
    values.any? ? (values.sum.to_f / values.size).round(1) : nil
  end

  def bool_rate(mps, attr)
    values = mps.map(&attr).compact
    return nil if values.empty?

    (values.count(&:itself) * 100.0 / values.size).round(1)
  end

  def calc_survival_stats(mps)
    mps_with_st = mps.select { |mp| (mp.survival_times || []).any? }
    return [] if mps_with_st.empty?

    max_lives = mps_with_st.map { |mp| mp.survival_times.size }.max

    max_lives.times.map do |i|
      mps_with_life = mps_with_st.select { |mp| mp.survival_times.size > i }

      # survival_times.size > deaths.to_i のとき最終ライフが生存で終わった
      survived = mps_with_life.select do |mp|
        mp.survival_times.size == i + 1 && mp.survival_times.size > mp.deaths.to_i
      end
      died = mps_with_life - survived

      {
        life:           i + 1,
        survived_cs:    avg_cs_value(survived, i),
        survived_count: survived.size,
        died_cs:        avg_cs_value(died, i),
        died_count:     died.size
      }
    end
  end

  def avg_cs_value(mps, life_index)
    values = mps.filter_map { |mp| mp.survival_times[life_index] }
    return nil if values.empty?

    (values.sum.to_f / values.size).round(0).to_i
  end
end
