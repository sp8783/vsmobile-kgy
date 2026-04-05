class StatisticsController < ApplicationController
  PERSONAL_TABS = %w[overview performance events event_progression mobile_suits opponent_suits partners opponents].freeze
  PERSONAL_SNAPSHOT_TABS = %w[overview events event_progression mobile_suits opponent_suits partners opponents].freeze

  before_action :authenticate_user!
  before_action :set_regular_users
  before_action :set_filters
  before_action :apply_filters

  def index
    @active_tab = params[:tab] || "overall"

    # ゲストユーザー（または管理者がゲスト視点切り替え中）は個人統計タブにアクセス不可
    if viewing_as_user.is_guest && PERSONAL_TABS.include?(@active_tab)
      redirect_to statistics_path(tab: "overall"), alert: "ゲストユーザーには個人統計データがありません"
      return
    end

    case @active_tab
    when *PERSONAL_SNAPSHOT_TABS
      assign_view_state(StatisticsPersonalTabSnapshot.new(tab: @active_tab, filtered_matches: @filtered_matches).to_h)
    when "overall"
      assign_view_state(StatisticsOverallSnapshot.new(filter_events: @filter_events).to_h)
    when "performance"
      calculate_performance_stats
    when "highlights"
      assign_view_state(StatisticsHighlightsSnapshot.new(filter_events: @filter_events).to_h)
    end

    set_filter_options
  end

  private

  def set_regular_users
    @regular_users = User.regular_users.order(:nickname)
  end

  def viewing_as_user
    return super if current_user&.is_admin

    if params[:view_user_id].present?
      User.regular_users.find_by(id: params[:view_user_id]) || current_user
    else
      current_user
    end
  end

  def set_filters
    @filter_events = selected_ids(:events)
    @filter_mobile_suits = selected_ids(:mobile_suits)
    @filter_partners = selected_ids(:partners)
    @filter_costs = selected_ids(:costs)
  end

  def apply_filters
    @filtered_matches = StatisticsFilteredMatchPlayersQuery.new(
      user: viewing_as_user,
      filter_events: @filter_events,
      filter_mobile_suits: @filter_mobile_suits,
      filter_partners: @filter_partners,
      filter_costs: @filter_costs
    ).call
  end

  # コミュニティ側クエリの基底スコープ（イベントフィルターのみ適用）
  def community_base_scope
    scope = MatchPlayer.joins(:match, :user).where(users: { is_guest: false })
    scope = scope.where(matches: { event_id: @filter_events }) if @filter_events.any?
    scope
  end

  def calculate_performance_stats
    stats_mps = @filtered_matches.select(&:has_stats?)
    win_mps  = stats_mps.select(&:won?)
    loss_mps = stats_mps.reject(&:won?)

    # 機体/コストフィルター適用時: フィルターなしの自分の全体平均・同コスト帯平均を算出（比較用）
    if @filter_mobile_suits.any? || @filter_costs.any?
      all_user_mps = MatchPlayer.where(user_id: viewing_as_user.id)
                                .joins(:match)
                                .includes(:match, :mobile_suit, :user, match: { rotation_match: :rotation })
      all_user_mps = all_user_mps.where(matches: { event_id: @filter_events }) if @filter_events.any?

      all_user_records = all_user_mps.to_a
      all_stats = all_user_records.select(&:has_stats?)
      @user_overall_avg    = calc_perf_stats(all_stats)
      @user_overall_wins   = calc_perf_stats(all_stats.select(&:won?))
      @user_overall_losses = calc_perf_stats(all_stats.reject(&:won?))

      # EXバースト活用分析の自己比較用データ（フィルターなし全体）
      all_loss_stats = all_stats.reject(&:won?)
      if all_loss_stats.any?
        n = all_loss_stats.size
        @user_overall_ex_remaining_rate  = (all_loss_stats.count { |mp| mp.last_death_ex_available || mp.survive_loss_ex_available } * 100.0 / n).round(1)
        @user_overall_last_death_ex_rate = (all_loss_stats.count { |mp| mp.last_death_ex_available } * 100.0 / n).round(1)
        @user_overall_survive_ex_rate    = (all_loss_stats.count { |mp| mp.survive_loss_ex_available } * 100.0 / n).round(1)
      end

      # OL分析の自己比較用データ（フィルターなし全体）
      all_user_losses_ol = all_user_records.reject(&:won?)
      all_user_wins_ol   = all_user_records.select(&:won?)
      if all_user_losses_ol.any?
        no_ol = all_user_losses_ol.count { |mp|
          flag = mp.team_number == 1 ? mp.match.team1_ex_overlimit_before_end : mp.match.team2_ex_overlimit_before_end
          flag == true
        }
        @user_overall_no_ol_loss_rate = (no_ol * 100.0 / all_user_losses_ol.size).round(1)
      end
      if all_user_wins_ol.any?
        opp_no_ol = all_user_wins_ol.count { |mp|
          flag = mp.team_number == 1 ? mp.match.team2_ex_overlimit_before_end : mp.match.team1_ex_overlimit_before_end
          flag == true
        }
        @user_overall_opp_no_ol_win_rate = (opp_no_ol * 100.0 / all_user_wins_ol.size).round(1)
      end

      # 同コスト帯平均: 機体フィルター時は絞った機体のコストを使用、コストフィルター時はそのコストを使用
      same_costs = if @filter_mobile_suits.any?
        MobileSuit.where(id: @filter_mobile_suits).pluck(:cost).uniq
      else
        @filter_costs
      end
      same_cost_stats   = all_stats.select { |mp| same_costs.include?(mp.mobile_suit.cost) }
      same_cost_records = all_user_records.select { |mp| same_costs.include?(mp.mobile_suit.cost) }
      # 絞り込み済みデータと実質同一になる場合（例: コストのみフィルター）は表示しない
      if same_cost_stats.size != stats_mps.select(&:has_stats?).size
        @user_same_cost_avg    = calc_perf_stats(same_cost_stats)
        @user_same_cost_wins   = calc_perf_stats(same_cost_stats.select(&:won?))
        @user_same_cost_losses = calc_perf_stats(same_cost_stats.reject(&:won?))
        @same_cost_label = same_costs.sort.reverse.map { |c| "#{c}" }.join("・") + "コスト"

        # EXバースト - 同コスト帯
        sc_loss_stats = same_cost_stats.reject(&:won?)
        if sc_loss_stats.any?
          n = sc_loss_stats.size
          @user_same_cost_ex_remaining_rate  = (sc_loss_stats.count { |mp| mp.last_death_ex_available || mp.survive_loss_ex_available } * 100.0 / n).round(1)
          @user_same_cost_last_death_ex_rate = (sc_loss_stats.count { |mp| mp.last_death_ex_available } * 100.0 / n).round(1)
          @user_same_cost_survive_ex_rate    = (sc_loss_stats.count { |mp| mp.survive_loss_ex_available } * 100.0 / n).round(1)
        end

        # OL分析 - 同コスト帯
        sc_losses_ol = same_cost_records.reject(&:won?)
        sc_wins_ol   = same_cost_records.select(&:won?)
        if sc_losses_ol.any?
          no_ol = sc_losses_ol.count { |mp|
            flag = mp.team_number == 1 ? mp.match.team1_ex_overlimit_before_end : mp.match.team2_ex_overlimit_before_end
            flag == true
          }
          @user_same_cost_no_ol_loss_rate = (no_ol * 100.0 / sc_losses_ol.size).round(1)
        end
        if sc_wins_ol.any?
          opp_no_ol = sc_wins_ol.count { |mp|
            flag = mp.team_number == 1 ? mp.match.team2_ex_overlimit_before_end : mp.match.team1_ex_overlimit_before_end
            flag == true
          }
          @user_same_cost_opp_no_ol_win_rate = (opp_no_ol * 100.0 / sc_wins_ol.size).round(1)
        end
      end
    end

    # by_user.each ループ内で win_mps/loss_mps が上書きされるため先に退避する
    user_win_mps  = win_mps
    user_loss_mps = loss_mps

    @stats_total  = stats_mps.size
    @stats_wins   = win_mps.size
    @stats_losses = loss_mps.size

    @performance_overall = calc_perf_stats(stats_mps)
    @performance_wins    = calc_perf_stats(win_mps)
    @performance_losses  = calc_perf_stats(loss_mps)

    # 敗北時のEXバースト残し
    @ex_remaining_on_loss    = loss_mps.count { |mp| mp.last_death_ex_available || mp.survive_loss_ex_available }
    @last_death_ex_on_loss   = loss_mps.count { |mp| mp.last_death_ex_available }
    @survive_loss_ex_on_loss = loss_mps.count { |mp| mp.survive_loss_ex_available }

    # OL分析（全試合対象）
    all_losses = @filtered_matches.reject(&:won?)
    all_wins   = @filtered_matches.select(&:won?)

    @my_team_no_ol_losses = all_losses.count do |mp|
      team_ol = mp.team_number == 1 ? mp.match.team1_ex_overlimit_before_end : mp.match.team2_ex_overlimit_before_end
      team_ol == true  # true = OL未発動（exbst-ov イベントなし）
    end
    @total_losses = all_losses.size

    @opponent_no_ol_wins = all_wins.count do |mp|
      opp_ol = mp.team_number == 1 ? mp.match.team2_ex_overlimit_before_end : mp.match.team1_ex_overlimit_before_end
      opp_ol == true  # true = 相手チームOL未発動
    end
    @total_wins_all = all_wins.size

    @has_ol_data = (all_losses + all_wins).any? { |mp|
      flag = mp.team_number == 1 ? mp.match.team1_ex_overlimit_before_end : mp.match.team2_ex_overlimit_before_end
      !flag.nil?
    }

    # EXバースト活用分析のコミュニティ分布（ユーザー別率 → avg/min/max）
    ex_loss_mps = community_base_scope.includes(:match)
      .where("matches.winning_team IS NOT NULL AND matches.winning_team != match_players.team_number")
      .where("last_death_ex_available IS NOT NULL OR survive_loss_ex_available IS NOT NULL")
      .to_a
    if ex_loss_mps.any?
      last_death_rates = []
      survive_rates    = []
      ex_rates = ex_loss_mps.group_by(&:user_id).map do |_uid, mps|
        n = mps.size
        remaining = mps.count { |mp| mp.last_death_ex_available || mp.survive_loss_ex_available }
        last_death_rates << (mps.count { |mp| mp.last_death_ex_available  } * 100.0 / n).round(1)
        survive_rates    << (mps.count { |mp| mp.survive_loss_ex_available } * 100.0 / n).round(1)
        (remaining * 100.0 / n).round(1)
      end
      @community_ex_remaining_rate  = (ex_rates.sum        / ex_rates.size).round(1)
      @community_ex_remaining_min   = ex_rates.min
      @community_ex_remaining_max   = ex_rates.max
      @community_last_death_ex_rate = (last_death_rates.sum / last_death_rates.size).round(1)
      @community_last_death_ex_min  = last_death_rates.min
      @community_last_death_ex_max  = last_death_rates.max
      @community_survive_ex_rate    = (survive_rates.sum    / survive_rates.size).round(1)
      @community_survive_ex_min     = survive_rates.min
      @community_survive_ex_max     = survive_rates.max
    end

    # OL分析のコミュニティ分布（ユーザー別率 → avg/min/max）
    ol_mps_all = community_base_scope.includes(:match)
      .where("matches.winning_team IS NOT NULL")
      .to_a
    if ol_mps_all.any?
      no_ol_loss_rates    = []
      opp_no_ol_win_rates = []
      ol_mps_all.group_by(&:user_id).each do |_uid, mps|
        loss_mps = mps.reject(&:won?)
        if loss_mps.any?
          no_ol = loss_mps.count { |mp|
            flag = mp.team_number == 1 ? mp.match.team1_ex_overlimit_before_end : mp.match.team2_ex_overlimit_before_end
            flag == true
          }
          no_ol_loss_rates << (no_ol * 100.0 / loss_mps.size).round(1)
        end
        win_mps = mps.select(&:won?)
        if win_mps.any?
          opp_no_ol = win_mps.count { |mp|
            flag = mp.team_number == 1 ? mp.match.team2_ex_overlimit_before_end : mp.match.team1_ex_overlimit_before_end
            flag == true
          }
          opp_no_ol_win_rates << (opp_no_ol * 100.0 / win_mps.size).round(1)
        end
      end
      if no_ol_loss_rates.any?
        @community_no_ol_loss_rate = (no_ol_loss_rates.sum / no_ol_loss_rates.size).round(1)
        @community_no_ol_loss_min  = no_ol_loss_rates.min
        @community_no_ol_loss_max  = no_ol_loss_rates.max
      end
      if opp_no_ol_win_rates.any?
        @community_opp_no_ol_win_rate = (opp_no_ol_win_rates.sum / opp_no_ol_win_rates.size).round(1)
        @community_opp_no_ol_win_min  = opp_no_ol_win_rates.min
        @community_opp_no_ol_win_max  = opp_no_ol_win_rates.max
      end
    end

    # コミュニティ平均を算出（基本パフォーマンス統計テーブル用）
    has_stats_sql = "score IS NOT NULL AND kills IS NOT NULL AND deaths IS NOT NULL AND " \
                    "damage_dealt IS NOT NULL AND damage_received IS NOT NULL AND exburst_damage IS NOT NULL"
    all_stats_mps = community_base_scope.includes(:match)
      .where(has_stats_sql).to_a
    if all_stats_mps.any?
      by_user = all_stats_mps.group_by(&:user_id)

      build_perf = lambda do |subset|
        m = subset.size
        next nil if m == 0
        sf = ->(f) { subset.sum { |mp| mp.send(f).to_f } }
        total_ex   = subset.sum { |mp| mp.exburst_count.to_i }
        total_ex_d = subset.sum { |mp| mp.exburst_deaths.to_i }
        ol_count = subset.count { |mp|
          flag = mp.team_number == 1 ? mp.match.team1_ex_overlimit_before_end : mp.match.team2_ex_overlimit_before_end
          flag == false
        }
        {
          score:              (sf.call(:score)          / m).round(1),
          kills:              (sf.call(:kills)           / m).round(2),
          deaths:             (sf.call(:deaths)          / m).round(2),
          damage_dealt:       (sf.call(:damage_dealt)    / m).round(0),
          damage_received:    (sf.call(:damage_received) / m).round(0),
          exburst_damage:            (sf.call(:exburst_damage)            / m).round(0),
          exburst_count:             (sf.call(:exburst_count)             / m).round(2),
          first_unit_exburst_count:  (sf.call(:first_unit_exburst_count)  / m).round(2),
          later_unit_exburst_count:  [ (sf.call(:exburst_count) - sf.call(:first_unit_exburst_count)) / m, 0 ].max.round(2),
          exburst_deaths:            (sf.call(:exburst_deaths)            / m).round(2),
          exburst_death_rate: total_ex > 0 ? (total_ex_d * 100.0 / total_ex).round(1) : nil,
          ol_rate:            (ol_count * 100.0 / m).round(1)
        }
      end

      build_community = lambda do |list|
        next nil unless list.any?
        n = list.size
        valid_dr = list.map { |u| u[:exburst_death_rate] }.compact
        avg = {
          score:              (list.sum { |u| u[:score] }          / n).round(1),
          kills:              (list.sum { |u| u[:kills] }           / n).round(2),
          deaths:             (list.sum { |u| u[:deaths] }          / n).round(2),
          damage_dealt:       (list.sum { |u| u[:damage_dealt] }    / n).round(0),
          damage_received:    (list.sum { |u| u[:damage_received] } / n).round(0),
          exburst_damage:            (list.sum { |u| u[:exburst_damage] }           / n).round(0),
          exburst_count:             (list.sum { |u| u[:exburst_count] }            / n).round(2),
          first_unit_exburst_count:  (list.sum { |u| u[:first_unit_exburst_count] } / n).round(2),
          later_unit_exburst_count:  (list.sum { |u| u[:later_unit_exburst_count] } / n).round(2),
          exburst_deaths:            (list.sum { |u| u[:exburst_deaths] }           / n).round(2),
          exburst_death_rate: valid_dr.any? ? (valid_dr.sum / valid_dr.size).round(1) : nil,
          ol_rate:            (list.sum { |u| u[:ol_rate] }         / n).round(1)
        }
        stat_keys = %i[score kills deaths damage_dealt damage_received exburst_damage exburst_count first_unit_exburst_count later_unit_exburst_count exburst_deaths ol_rate]
        min_h = stat_keys.to_h { |k| [ k, list.map { |u| u[k] }.compact.min ] }
        max_h = stat_keys.to_h { |k| [ k, list.map { |u| u[k] }.compact.max ] }
        if valid_dr.any?
          min_h[:exburst_death_rate] = valid_dr.min
          max_h[:exburst_death_rate] = valid_dr.max
        end
        [ avg, min_h, max_h ]
      end

      user_perf_list   = []
      user_wins_list   = []
      user_losses_list = []
      by_user.each do |_uid, mps|
        overall  = build_perf.call(mps)
        win_mps  = mps.select(&:won?)
        loss_mps = mps.reject(&:won?).select { |mp| mp.match.winning_team.present? }
        user_perf_list   << overall                    if overall
        user_wins_list   << build_perf.call(win_mps)   if win_mps.any?
        user_losses_list << build_perf.call(loss_mps)  if loss_mps.any?
      end

      if user_perf_list.any?
        result = build_community.call(user_perf_list)
        @community_avg, @community_min, @community_max = result if result
      end
      if user_wins_list.any?
        result = build_community.call(user_wins_list)
        @community_wins_avg, @community_wins_min, @community_wins_max = result if result
      end
      if user_losses_list.any?
        result = build_community.call(user_losses_list)
        @community_losses_avg, @community_losses_min, @community_losses_max = result if result
      end
    end

    # 生存時間統計（全体・勝利時・敗北時）
    # 注意: by_user.each ループ内で win_mps/loss_mps が上書きされるため、事前に退避した変数を使う
    @survival_time_stats         = calculate_survival_time_stats(stats_mps,       community_scope: :all)
    @survival_time_stats_wins    = calculate_survival_time_stats(user_win_mps,    community_scope: :wins)
    @survival_time_stats_losses  = calculate_survival_time_stats(user_loss_mps,   community_scope: :losses)
  end

  def calc_perf_stats(mps)
    n = mps.size
    return nil if n == 0

    # nil フィールドを除外して平均を計算する（nil.to_f = 0 による不正な平均を防ぐ）
    avg_field = ->(field) {
      valid = mps.select { |mp| mp.send(field).present? }
      valid.any? ? (valid.sum { |mp| mp.send(field).to_f } / valid.size) : nil
    }
    {
      count:           n,
      score:           avg_field.call(:score)&.round(1),
      kills:           avg_field.call(:kills)&.round(2),
      deaths:          avg_field.call(:deaths)&.round(2),
      damage_dealt:    avg_field.call(:damage_dealt)&.round(0),
      damage_received: avg_field.call(:damage_received)&.round(0),
      exburst_damage:           avg_field.call(:exburst_damage)&.round(0),
      exburst_count:            avg_field.call(:exburst_count)&.round(2),
      first_unit_exburst_count: avg_field.call(:first_unit_exburst_count)&.round(2),
      later_unit_exburst_count: begin
                                  ec = avg_field.call(:exburst_count)
                                  fec = avg_field.call(:first_unit_exburst_count)
                                  (ec && fec) ? [ (ec - fec).round(2), 0 ].max : nil
                                end,
      exburst_deaths:           avg_field.call(:exburst_deaths)&.round(2),
      exburst_death_rate: begin
                            total_count  = mps.sum { |mp| mp.exburst_count.to_i }
                            total_deaths = mps.sum { |mp| mp.exburst_deaths.to_i }
                            total_count > 0 ? (total_deaths * 100.0 / total_count).round(1) : nil
                          end,
      ol_rate:         (mps.count { |mp|
                         flag = mp.team_number == 1 ? mp.match.team1_ex_overlimit_before_end : mp.match.team2_ex_overlimit_before_end
                         flag == false
                       } * 100.0 / n).round(1)
    }
  end

  # 生存時間統計を計算する
  # @param user_mps [Array<MatchPlayer>] フィルター済みのユーザー match_player 一覧
  # @param community_scope [Symbol] :all / :wins / :losses — コミュニティ側の勝敗絞り込み
  # @return [Array<Hash>] ライフ番号ごとの統計配列。survival_times データがない場合は []
  def calculate_survival_time_stats(user_mps, community_scope: :all)
    # survival_times が存在するものだけ対象
    user_st_mps = user_mps.select { |mp| mp.survival_times.present? }
    return [] if user_st_mps.empty?

    # コミュニティデータ（非ゲストかつ survival_times 存在）
    community_q = community_base_scope
      .where("survival_times IS NOT NULL AND jsonb_array_length(survival_times) > 0")
    community_q = case community_scope
    when :wins   then community_q.where("matches.winning_team = match_players.team_number")
    when :losses then community_q.where("matches.winning_team != match_players.team_number")
    else community_q
    end
    community_mps = community_q.to_a

    # 最大ライフ数を決定（ユーザーとコミュニティ両方から）
    max_lives = [ user_st_mps, community_mps ].flat_map { |mps|
      mps.map { |mp| (mp.survival_times || []).size }
    }.max.to_i
    return [] if max_lives == 0

    max_lives.times.map do |n|
      mps_with_life  = user_st_mps.select    { |mp| (mp.survival_times || []).size > n }
      comm_with_life = community_mps.select  { |mp| (mp.survival_times || []).size > n }

      # 死亡・生存を分離（survival_times.size > deaths なら最終ライフは生存）
      survived_life = ->(mp, idx) {
        st = mp.survival_times || []
        idx == st.size - 1 && st.size > mp.deaths.to_i
      }
      user_died_mps     = mps_with_life.reject  { |mp| survived_life.(mp, n) }
      user_survived_mps = mps_with_life.select  { |mp| survived_life.(mp, n) }
      comm_died_mps     = comm_with_life.reject  { |mp| survived_life.(mp, n) }
      comm_survived_mps = comm_with_life.select  { |mp| survived_life.(mp, n) }

      # 死亡統計
      died_values    = user_died_mps.map { |mp| mp.survival_times[n] }
      died_avg_cs    = died_values.any? ? (died_values.sum.to_f / died_values.size).round : nil
      died_comm_avgs = comm_died_mps.group_by(&:user_id).filter_map do |_uid, mps|
        vals = mps.map { |mp| (mp.survival_times || [])[n] }.compact
        next unless vals.any?
        (vals.sum.to_f / vals.size).round
      end

      # 生存統計（全ライフ実時間あり）
      survived_values    = user_survived_mps.map { |mp| mp.survival_times[n] }
      survived_avg_cs    = survived_values.any? ? (survived_values.sum.to_f / survived_values.size).round : nil
      survived_comm_avgs = comm_survived_mps.group_by(&:user_id).filter_map do |_uid, mps|
        vals = mps.map { |mp| (mp.survival_times || [])[n] }.compact
        next unless vals.any?
        (vals.sum.to_f / vals.size).round
      end

      {
        n: n + 1,
        died: {
          user_count:       user_died_mps.size,
          user_avg_cs:      died_avg_cs,
          community_avg_cs: died_comm_avgs.any? ? (died_comm_avgs.sum.to_f / died_comm_avgs.size).round : nil,
          community_min_cs: died_comm_avgs.min,
          community_max_cs: died_comm_avgs.max
        },
        survived: {
          user_count:       user_survived_mps.size,
          user_avg_cs:      survived_avg_cs,
          community_avg_cs: survived_comm_avgs.any? ? (survived_comm_avgs.sum.to_f / survived_comm_avgs.size).round : nil,
          community_min_cs: survived_comm_avgs.min,
          community_max_cs: survived_comm_avgs.max
        }
      }
    end
  end

  def selected_ids(param_key)
    params[param_key].present? ? params[param_key].map(&:to_i) : []
  end

  def assign_view_state(attributes)
    attributes.each do |name, value|
      instance_variable_set("@#{name}", value)
    end
  end

  def set_filter_options
    filter_options = StatisticsFilterOptions.new(
      user: viewing_as_user,
      filter_events: @filter_events
    ).to_h

    @all_events = filter_options[:all_events]
    @all_mobile_suits = filter_options[:all_mobile_suits]
    @all_partners = filter_options[:all_partners]
  end
end
