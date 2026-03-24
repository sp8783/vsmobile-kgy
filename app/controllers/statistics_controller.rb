class StatisticsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_regular_users
  before_action :set_filters
  before_action :apply_filters

  def index
    @active_tab = params[:tab] || "overall"

    # ゲストユーザー（または管理者がゲスト視点切り替え中）は個人統計タブにアクセス不可
    personal_tabs = %w[overview performance events event_progression mobile_suits opponent_suits partners opponents]
    if viewing_as_user.is_guest && personal_tabs.include?(@active_tab)
      redirect_to statistics_path(tab: "overall"), alert: "ゲストユーザーには個人統計データがありません"
      return
    end

    case @active_tab
    when "overview"
      calculate_overview_stats
    when "overall"
      calculate_overall_stats
    when "partners"
      calculate_partner_stats
    when "mobile_suits"
      calculate_mobile_suit_stats
    when "opponent_suits"
      calculate_mobile_suit_stats
    when "events"
      calculate_event_stats
    when "event_progression"
      calculate_event_progression_stats
    when "opponents"
      calculate_opponent_stats
    when "performance"
      calculate_performance_stats
    when "highlights"
      calculate_highlights
    end

    # フィルター用のデータ
    @all_events = Event.order(held_on: :desc)
    @all_mobile_suits = MobileSuit.order(:name)
    all_partners = User.regular_users.where.not(id: viewing_as_user.id).order(:nickname)
    if @filter_events.any?
      partner_ids_in_events = MatchPlayer.joins(:match)
                                         .where(matches: { event_id: @filter_events })
                                         .where.not(user_id: viewing_as_user.id)
                                         .distinct
                                         .pluck(:user_id)
      all_partners = all_partners.where(id: partner_ids_in_events)
    end
    @all_partners = all_partners
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
    @filter_events = params[:events].present? ? params[:events].map(&:to_i) : []
    @filter_mobile_suits = params[:mobile_suits].present? ? params[:mobile_suits].map(&:to_i) : []
    @filter_partners = params[:partners].present? ? params[:partners].map(&:to_i) : []
    @filter_costs = params[:costs].present? ? params[:costs].map(&:to_i) : []
  end

  def apply_filters
    # ログインユーザーの試合を基準に開始
    @filtered_matches = MatchPlayer.where(user_id: viewing_as_user.id)
                                   .joins(:match)
                                   .includes(:match, :mobile_suit, :user, match: { rotation_match: :rotation })

    # イベントフィルター
    if @filter_events.any?
      @filtered_matches = @filtered_matches.where(matches: { event_id: @filter_events })
    end

    # 機体フィルター（ログインユーザーが使用した機体）
    if @filter_mobile_suits.any?
      @filtered_matches = @filtered_matches.where(mobile_suit_id: @filter_mobile_suits)
    end

    # コストフィルター（ログインユーザーが使用した機体のコスト）
    if @filter_costs.any?
      @filtered_matches = @filtered_matches.where(mobile_suit_id: MobileSuit.where(cost: @filter_costs))
    end

    # パートナーフィルター
    if @filter_partners.any?
      # パートナーが参加している試合を取得
      partner_match_ids = MatchPlayer.where(user_id: @filter_partners)
                                     .pluck(:match_id)
                                     .uniq

      # ログインユーザーとパートナーが同じチームの試合に絞り込む
      filtered_match_ids = []
      @filtered_matches.each do |my_mp|
        match = my_mp.match
        my_team = my_mp.team_number

        # この試合にパートナーが同じチームで参加しているか確認
        partner_in_same_team = match.match_players.any? do |mp|
          @filter_partners.include?(mp.user_id) && mp.team_number == my_team
        end

        filtered_match_ids << match.id if partner_in_same_team
      end

      @filtered_matches = @filtered_matches.where(matches: { id: filtered_match_ids.uniq })
    end
  end

  # コミュニティ側クエリの基底スコープ（イベントフィルターのみ適用）
  def community_base_scope
    scope = MatchPlayer.joins(:match, :user).where(users: { is_guest: false })
    scope = scope.where(matches: { event_id: @filter_events }) if @filter_events.any?
    scope
  end

  def calculate_overview_stats
    # サマリーカード用の統計
    @total_matches = @filtered_matches.count

    wins = @filtered_matches.count do |mp|
      mp.match.winning_team == mp.team_number
    end
    @total_wins = wins
    @win_rate = @total_matches > 0 ? (wins.to_f / @total_matches * 100).round(1) : 0

    # 最多連勝記録を計算
    @max_winning_streak = calculate_max_streak

    # イベント別勝率の推移
    @event_win_rates = calculate_event_win_rates

    # コスト帯別勝率
    @cost_win_rates = calculate_cost_win_rates

    # ローテーション周回別勝率
    @rotation_round_stats = calculate_rotation_round_stats
  end

  def calculate_max_streak
    # 全試合を時系列順に取得
    all_matches = @filtered_matches.order("matches.played_at ASC").to_a

    max_streak = 0
    current_streak = 0

    all_matches.each do |mp|
      if mp.match.winning_team == mp.team_number
        current_streak += 1
        max_streak = [ max_streak, current_streak ].max
      else
        current_streak = 0
      end
    end

    max_streak
  end

  def calculate_event_win_rates
    events_data = {}

    @filtered_matches.each do |mp|
      event_id = mp.match.event_id
      event = mp.match.event

      events_data[event_id] ||= {
        event: event,
        wins: 0,
        total: 0
      }

      events_data[event_id][:total] += 1
      events_data[event_id][:wins] += 1 if mp.match.winning_team == mp.team_number
    end

    events_data.map do |event_id, data|
      {
        event: data[:event],
        win_rate: data[:total] > 0 ? (data[:wins].to_f / data[:total] * 100).round(1) : 0,
        total: data[:total]
      }
    end.sort_by { |d| d[:event].held_on }
  end

  def calculate_cost_win_rates
    cost_data = Hash.new { |h, k| h[k] = { wins: 0, total: 0 } }

    @filtered_matches.each do |my_mp|
      match = my_mp.match
      my_team = my_mp.team_number
      my_cost = my_mp.mobile_suit.cost

      partner_mp = match.match_players.find do |mp|
        mp.team_number == my_team && mp.user_id != viewing_as_user.id
      end

      partner_cost = partner_mp&.mobile_suit&.cost
      cost_key = [ my_cost, partner_cost ]

      cost_data[cost_key][:total] += 1
      cost_data[cost_key][:wins] += 1 if match.winning_team == my_team
    end

    cost_data.map do |cost_key, data|
      my_cost, partner_cost = cost_key
      wins = data[:wins]
      total = data[:total]
      {
        my_cost: my_cost,
        partner_cost: partner_cost,
        wins: wins,
        losses: total - wins,
        total: total,
        win_rate: total > 0 ? (wins.to_f / total * 100).round(1) : 0
      }
    end.sort_by { |d| [ -d[:my_cost], -(d[:partner_cost] || 0) ] }
  end

  def calculate_rotation_round_stats
    # RotationMatchがある場合のみ計算
    round_data = Hash.new { |h, k| h[k] = { wins: 0, total: 0 } }

    @filtered_matches.each do |my_mp|
      match = my_mp.match

      # rotation_matchがある場合、round_numberを取得
      if match.rotation_match&.rotation
        round_number = match.rotation_match.rotation.round_number

        round_data[round_number][:total] += 1
        round_data[round_number][:wins] += 1 if match.winning_team == my_mp.team_number
      end
    end

    round_data.map do |round_num, data|
      {
        round_number: round_num,
        wins: data[:wins],
        total: data[:total],
        losses: data[:total] - data[:wins],
        win_rate: data[:total] > 0 ? (data[:wins].to_f / data[:total] * 100).round(1) : 0
      }
    end.sort_by { |d| d[:round_number] }
  end

  def calculate_partner_stats
    partner_data = Hash.new do |h, k|
      h[k] = {
        user: nil,
        wins: 0,
        total: 0,
        suit_combinations: Hash.new(0),
        last_played_at: nil
      }
    end

    @filtered_matches.each do |my_mp|
      match = my_mp.match
      my_team = my_mp.team_number

      # パートナーを見つける
      partner_mp = match.match_players.find do |mp|
        mp.team_number == my_team && mp.user_id != viewing_as_user.id
      end

      next unless partner_mp

      partner_id = partner_mp.user_id
      partner_data[partner_id][:user] = partner_mp.user
      partner_data[partner_id][:total] += 1
      partner_data[partner_id][:wins] += 1 if match.winning_team == my_team

      # 機体の組み合わせを記録
      combo_key = "#{my_mp.mobile_suit.name} & #{partner_mp.mobile_suit.name}"
      partner_data[partner_id][:suit_combinations][combo_key] += 1

      # 最終対戦日を更新
      if partner_data[partner_id][:last_played_at].nil? || match.played_at > partner_data[partner_id][:last_played_at]
        partner_data[partner_id][:last_played_at] = match.played_at
      end
    end

    @partners_list = partner_data.map do |partner_id, data|
      {
        user: data[:user],
        wins: data[:wins],
        total: data[:total],
        win_rate: data[:total] > 0 ? (data[:wins].to_f / data[:total] * 100).round(1) : 0,
        top_combinations: data[:suit_combinations].sort_by { |_, count| -count }.take(3).to_h,
        last_played_at: data[:last_played_at]
      }
    end.sort_by { |p| -p[:win_rate] }
  end

  def calculate_mobile_suit_stats
    # 使用機体の統計
    suit_data = Hash.new do |h, k|
      h[k] = {
        mobile_suit: nil,
        wins: 0,
        total: 0,
        partner_suits: Hash.new(0),
        last_used_at: nil,
        stats_mps: []
      }
    end

    # 対戦機体の統計
    opponent_suit_data = Hash.new do |h, k|
      h[k] = {
        mobile_suit: nil,
        wins: 0,
        total: 0,
        last_faced_at: nil
      }
    end

    @filtered_matches.each do |my_mp|
      match = my_mp.match
      my_team = my_mp.team_number
      suit_id = my_mp.mobile_suit_id
      opponent_team = my_team == 1 ? 2 : 1

      # 使用機体の統計
      suit_data[suit_id][:mobile_suit] = my_mp.mobile_suit
      suit_data[suit_id][:total] += 1
      suit_data[suit_id][:wins] += 1 if match.winning_team == my_team

      # パートナーの機体を記録
      partner_mp = match.match_players.find do |mp|
        mp.team_number == my_team && mp.user_id != viewing_as_user.id
      end

      if partner_mp
        suit_data[suit_id][:partner_suits][partner_mp.mobile_suit.name] += 1
      end

      # has_stats? な試合のみ収集
      suit_data[suit_id][:stats_mps] << my_mp if my_mp.has_stats?

      # 最終使用日を更新
      if suit_data[suit_id][:last_used_at].nil? || match.played_at > suit_data[suit_id][:last_used_at]
        suit_data[suit_id][:last_used_at] = match.played_at
      end

      # 対戦機体の統計
      match.match_players.select { |mp| mp.team_number == opponent_team }.each do |opponent_mp|
        opp_suit_id = opponent_mp.mobile_suit_id
        opponent_suit_data[opp_suit_id][:mobile_suit] = opponent_mp.mobile_suit
        opponent_suit_data[opp_suit_id][:total] += 1
        opponent_suit_data[opp_suit_id][:wins] += 1 if match.winning_team == my_team

        # 最終対戦日を更新
        if opponent_suit_data[opp_suit_id][:last_faced_at].nil? || match.played_at > opponent_suit_data[opp_suit_id][:last_faced_at]
          opponent_suit_data[opp_suit_id][:last_faced_at] = match.played_at
        end
      end
    end

    @mobile_suits_list = suit_data.map do |suit_id, data|
      stats = data[:stats_mps]
      avg_k = stats.any? ? stats.sum { |mp| mp.kills.to_f } / stats.size : nil
      avg_d = stats.any? ? stats.sum { |mp| mp.deaths.to_f } / stats.size : nil
      {
        mobile_suit: data[:mobile_suit],
        wins: data[:wins],
        total: data[:total],
        win_rate: data[:total] > 0 ? (data[:wins].to_f / data[:total] * 100).round(1) : 0,
        top_partner_suits: data[:partner_suits].sort_by { |_, count| -count }.take(3).to_h,
        last_used_at: data[:last_used_at],
        avg_score: stats.any? ? (stats.sum { |mp| mp.score.to_f } / stats.size).round(1) : nil,
        kd_ratio: (avg_k && avg_d && avg_d > 0) ? (avg_k / avg_d).round(2) : avg_k&.round(2)
      }
    end.sort_by { |s| -s[:total] }

    @opponent_suits_list = opponent_suit_data.map do |suit_id, data|
      {
        mobile_suit: data[:mobile_suit],
        wins: data[:wins],
        total: data[:total],
        win_rate: data[:total] > 0 ? (data[:wins].to_f / data[:total] * 100).round(1) : 0,
        last_faced_at: data[:last_faced_at]
      }
    end.sort_by { |s| -s[:total] }
  end

  def calculate_event_stats
    event_data = Hash.new do |h, k|
      h[k] = {
        event: nil,
        wins: 0,
        total: 0,
        suits_used: Hash.new(0),
        partners: Hash.new(0)
      }
    end

    @filtered_matches.each do |my_mp|
      match = my_mp.match
      my_team = my_mp.team_number
      event_id = match.event_id

      event_data[event_id][:event] = match.event
      event_data[event_id][:total] += 1
      event_data[event_id][:wins] += 1 if match.winning_team == my_team
      event_data[event_id][:suits_used][my_mp.mobile_suit.name] += 1

      # パートナーを記録
      partner_mp = match.match_players.find do |mp|
        mp.team_number == my_team && mp.user_id != viewing_as_user.id
      end

      if partner_mp
        event_data[event_id][:partners][partner_mp.user.nickname] += 1
      end
    end

    @events_list = event_data.map do |event_id, data|
      {
        event: data[:event],
        wins: data[:wins],
        total: data[:total],
        win_rate: data[:total] > 0 ? (data[:wins].to_f / data[:total] * 100).round(1) : 0,
        top_suits: data[:suits_used].sort_by { |_, count| -count }.take(3).to_h,
        top_partners: data[:partners].sort_by { |_, count| -count }.take(3).to_h
      }
    end.sort_by { |e| e[:event].held_on }.reverse
  end

  def calculate_opponent_stats
    opponent_data = Hash.new do |h, k|
      h[k] = {
        user: nil,
        wins: 0,
        total: 0,
        suits_used: Hash.new(0),
        last_played_at: nil
      }
    end

    @filtered_matches.each do |my_mp|
      match = my_mp.match
      my_team = my_mp.team_number
      opponent_team = my_team == 1 ? 2 : 1

      # 対戦相手を取得
      match.match_players.select { |mp| mp.team_number == opponent_team }.each do |opponent_mp|
        opponent_id = opponent_mp.user_id
        opponent_data[opponent_id][:user] = opponent_mp.user
        opponent_data[opponent_id][:total] += 1
        opponent_data[opponent_id][:wins] += 1 if match.winning_team == my_team
        opponent_data[opponent_id][:suits_used][opponent_mp.mobile_suit.name] += 1

        # 最終対戦日を更新
        if opponent_data[opponent_id][:last_played_at].nil? || match.played_at > opponent_data[opponent_id][:last_played_at]
          opponent_data[opponent_id][:last_played_at] = match.played_at
        end
      end
    end

    @opponents_list = opponent_data.map do |opponent_id, data|
      {
        user: data[:user],
        wins: data[:wins],
        total: data[:total],
        win_rate: data[:total] > 0 ? (data[:wins].to_f / data[:total] * 100).round(1) : 0,
        top_suits: data[:suits_used].sort_by { |_, count| -count }.take(3).to_h,
        last_played_at: data[:last_played_at]
      }
    end.sort_by { |o| -o[:total] }
  end

  def calculate_event_progression_stats
    # イベントごとにデータを集計
    event_progression_data = Hash.new do |h, k|
      h[k] = {
        event: nil,
        has_rotation: false,
        rotations: Hash.new { |h2, k2| h2[k2] = { wins: 0, total: 0, rotation_name: nil, matches: [] } },
        all_matches: []
      }
    end

    @filtered_matches.each do |my_mp|
      match = my_mp.match
      my_team = my_mp.team_number
      event_id = match.event_id

      event_progression_data[event_id][:event] = match.event
      event_progression_data[event_id][:all_matches] << my_mp

      # rotation_matchがある場合、ローテーション情報を取得
      if match.rotation_match && match.rotation_match.rotation
        event_progression_data[event_id][:has_rotation] = true
        rotation_id = match.rotation_match.rotation_id
        round_number = match.rotation_match.rotation.round_number

        event_progression_data[event_id][:rotations][rotation_id][:rotation_name] = "#{round_number}周目"
        event_progression_data[event_id][:rotations][rotation_id][:total] += 1
        event_progression_data[event_id][:rotations][rotation_id][:wins] += 1 if match.winning_team == my_team
        event_progression_data[event_id][:rotations][rotation_id][:matches] << my_mp
      end
    end

    @event_progression_list = event_progression_data.map do |event_id, data|
      if data[:has_rotation]
        # ローテーションがある場合：ローテーション別に表示
        rotations_stats = data[:rotations].map do |rotation_id, rotation_data|
          {
            rotation_name: rotation_data[:rotation_name],
            wins: rotation_data[:wins],
            total: rotation_data[:total],
            losses: rotation_data[:total] - rotation_data[:wins],
            win_rate: rotation_data[:total] > 0 ? (rotation_data[:wins].to_f / rotation_data[:total] * 100).round(1) : 0
          }
        end
      else
        # ローテーションがない場合：試合を時系列順に4等分（ターム表示）
        sorted_matches = data[:all_matches].sort_by { |mp| mp.match.played_at }
        total_matches = sorted_matches.size

        if total_matches > 0
          # 4等分（第1ターム、第2ターム、第3ターム、第4ターム）
          quarter_size = (total_matches / 4.0).ceil
          quarters = [
            { name: "第1ターム", matches: sorted_matches[0...quarter_size] },
            { name: "第2ターム", matches: sorted_matches[quarter_size...(quarter_size * 2)] },
            { name: "第3ターム", matches: sorted_matches[(quarter_size * 2)...(quarter_size * 3)] },
            { name: "第4ターム", matches: sorted_matches[(quarter_size * 3)..-1] }
          ]

          rotations_stats = quarters.map do |quarter|
            next if quarter[:matches].nil? || quarter[:matches].empty?

            wins = quarter[:matches].count { |mp| mp.match.winning_team == mp.team_number }
            total = quarter[:matches].size

            {
              rotation_name: quarter[:name],
              wins: wins,
              total: total,
              losses: total - wins,
              win_rate: total > 0 ? (wins.to_f / total * 100).round(1) : 0
            }
          end.compact
        else
          rotations_stats = []
        end
      end

      {
        event: data[:event],
        has_rotation: data[:has_rotation],
        rotations: rotations_stats,
        total_matches: rotations_stats.sum { |r| r[:total] },
        overall_win_rate: rotations_stats.sum { |r| r[:total] } > 0 ?
          (rotations_stats.sum { |r| r[:wins] }.to_f / rotations_stats.sum { |r| r[:total] } * 100).round(1) : 0
      }
    end.select { |e| e[:rotations].any? }.sort_by { |e| e[:event].held_on }.reverse
  end

  def calculate_performance_stats
    stats_mps = @filtered_matches.select(&:has_stats?)
    win_mps  = stats_mps.select { |mp| mp.match.winning_team == mp.team_number }
    loss_mps = stats_mps.reject { |mp| mp.match.winning_team == mp.team_number }

    # 機体/コストフィルター適用時: フィルターなしの自分の全体平均・同コスト帯平均を算出（比較用）
    if @filter_mobile_suits.any? || @filter_costs.any?
      all_user_mps = MatchPlayer.where(user_id: viewing_as_user.id)
                                .joins(:match)
                                .includes(:match, :mobile_suit, :user, match: { rotation_match: :rotation })
      all_user_mps = all_user_mps.where(matches: { event_id: @filter_events }) if @filter_events.any?

      all_user_records = all_user_mps.to_a
      all_stats = all_user_records.select(&:has_stats?)
      @user_overall_avg    = calc_perf_stats(all_stats)
      @user_overall_wins   = calc_perf_stats(all_stats.select { |mp| mp.match.winning_team == mp.team_number })
      @user_overall_losses = calc_perf_stats(all_stats.reject { |mp| mp.match.winning_team == mp.team_number })

      # EXバースト活用分析の自己比較用データ（フィルターなし全体）
      all_loss_stats = all_stats.reject { |mp| mp.match.winning_team == mp.team_number }
      if all_loss_stats.any?
        n = all_loss_stats.size
        @user_overall_ex_remaining_rate  = (all_loss_stats.count { |mp| mp.last_death_ex_available || mp.survive_loss_ex_available } * 100.0 / n).round(1)
        @user_overall_last_death_ex_rate = (all_loss_stats.count { |mp| mp.last_death_ex_available } * 100.0 / n).round(1)
        @user_overall_survive_ex_rate    = (all_loss_stats.count { |mp| mp.survive_loss_ex_available } * 100.0 / n).round(1)
      end

      # OL分析の自己比較用データ（フィルターなし全体）
      all_user_losses_ol = all_user_records.reject { |mp| mp.match.winning_team == mp.team_number }
      all_user_wins_ol   = all_user_records.select { |mp| mp.match.winning_team == mp.team_number }
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
        @user_same_cost_wins   = calc_perf_stats(same_cost_stats.select { |mp| mp.match.winning_team == mp.team_number })
        @user_same_cost_losses = calc_perf_stats(same_cost_stats.reject { |mp| mp.match.winning_team == mp.team_number })
        @same_cost_label = same_costs.sort.reverse.map { |c| "#{c}" }.join("・") + "コスト"

        # EXバースト - 同コスト帯
        sc_loss_stats = same_cost_stats.reject { |mp| mp.match.winning_team == mp.team_number }
        if sc_loss_stats.any?
          n = sc_loss_stats.size
          @user_same_cost_ex_remaining_rate  = (sc_loss_stats.count { |mp| mp.last_death_ex_available || mp.survive_loss_ex_available } * 100.0 / n).round(1)
          @user_same_cost_last_death_ex_rate = (sc_loss_stats.count { |mp| mp.last_death_ex_available } * 100.0 / n).round(1)
          @user_same_cost_survive_ex_rate    = (sc_loss_stats.count { |mp| mp.survive_loss_ex_available } * 100.0 / n).round(1)
        end

        # OL分析 - 同コスト帯
        sc_losses_ol = same_cost_records.reject { |mp| mp.match.winning_team == mp.team_number }
        sc_wins_ol   = same_cost_records.select { |mp| mp.match.winning_team == mp.team_number }
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
    all_losses = @filtered_matches.reject { |mp| mp.match.winning_team == mp.team_number }
    all_wins   = @filtered_matches.select { |mp| mp.match.winning_team == mp.team_number }

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
        loss_mps = mps.select { |mp| mp.match.winning_team != mp.team_number }
        if loss_mps.any?
          no_ol = loss_mps.count { |mp|
            flag = mp.team_number == 1 ? mp.match.team1_ex_overlimit_before_end : mp.match.team2_ex_overlimit_before_end
            flag == true
          }
          no_ol_loss_rates << (no_ol * 100.0 / loss_mps.size).round(1)
        end
        win_mps = mps.select { |mp| mp.match.winning_team == mp.team_number }
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
          exburst_damage:     (sf.call(:exburst_damage)  / m).round(0),
          exburst_count:      (sf.call(:exburst_count)   / m).round(2),
          exburst_deaths:     (sf.call(:exburst_deaths)  / m).round(2),
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
          exburst_damage:     (list.sum { |u| u[:exburst_damage] }  / n).round(0),
          exburst_count:      (list.sum { |u| u[:exburst_count] }   / n).round(2),
          exburst_deaths:     (list.sum { |u| u[:exburst_deaths] }  / n).round(2),
          exburst_death_rate: valid_dr.any? ? (valid_dr.sum / valid_dr.size).round(1) : nil,
          ol_rate:            (list.sum { |u| u[:ol_rate] }         / n).round(1)
        }
        stat_keys = %i[score kills deaths damage_dealt damage_received exburst_damage exburst_count exburst_deaths ol_rate]
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
        win_mps  = mps.select { |mp| mp.match.winning_team == mp.team_number }
        loss_mps = mps.select { |mp| mp.match.winning_team && mp.match.winning_team != mp.team_number }
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
      exburst_damage:  avg_field.call(:exburst_damage)&.round(0),
      exburst_count:   avg_field.call(:exburst_count)&.round(2),
      exburst_deaths:  avg_field.call(:exburst_deaths)&.round(2),
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

  def calculate_highlights
    base_mps = MatchPlayer.joins(:match, :mobile_suit, :user)
                          .includes(:match, :mobile_suit, :user, match: :event)
    base_mps = base_mps.where(matches: { event_id: @filter_events }) if @filter_events.any?

    stats_mps = base_mps.where.not(damage_dealt: nil)

    # 最多ダメージ
    @highlight_most_damage = stats_mps.order(damage_dealt: :desc).first

    # 最多 EX バーストダメージ
    @highlight_most_exburst_damage = base_mps.where.not(exburst_damage: nil)
                                             .order(exburst_damage: :desc).first

    # 最少被ダメージ（勝利プレイヤー単位）
    @highlight_min_damage_received = MatchPlayer
      .joins(:match, :mobile_suit, :user)
      .includes(:match, :mobile_suit, :user, match: :event)
      .where.not(damage_received: nil)
      .where("matches.winning_team = match_players.team_number")
      .then { |q| @filter_events.any? ? q.where(matches: { event_id: @filter_events }) : q }
      .order(damage_received: :asc)
      .first

    # 最高スコア
    @highlight_top_score = base_mps.where.not(score: nil).order(score: :desc).first

    # 最も激しい試合（全プレイヤーの damage_dealt 合計が最大の試合）
    intense_mps = MatchPlayer.joins(:match)
      .includes(match: :event)
      .where.not(damage_dealt: nil)
    intense_mps = intense_mps.where(matches: { event_id: @filter_events }) if @filter_events.any?

    best_intense = intense_mps.to_a
      .group_by(&:match_id)
      .filter_map do |_mid, mps|
        next if mps.any? { |mp| mp.damage_dealt.nil? }
        [ mps.sum(&:damage_dealt), mps.first.match ]
      end
      .max_by { |total, _| total }

    if best_intense
      @highlight_most_intense_total = best_intense[0]
      @highlight_most_intense_match = best_intense[1]
    end

    # 生存時間: survival_times[0] があるものだけ対象
    survival_mps = base_mps.where("survival_times IS NOT NULL AND jsonb_array_length(survival_times) > 0")

    loaded_survival = survival_mps.to_a

    # 最長 1 機体目生存時間（死亡・生存問わず）
    longest_life_mp = loaded_survival.max_by { |mp| (mp.survival_times || [])[0].to_i }
    @highlight_longest_first_life    = longest_life_mp
    @highlight_longest_first_life_cs = longest_life_mp ? (longest_life_mp.survival_times || [])[0].to_i : nil

    # 最短 1 機体目生存時間（死亡のみ = survival_times が 2 個以上 OR deaths >= 1）
    died_on_first = loaded_survival.select do |mp|
      st = mp.survival_times || []
      st.size >= 2 || mp.deaths.to_i >= 1
    end
    shortest_life_mp = died_on_first.min_by { |mp| (mp.survival_times || [])[0].to_i }
    @highlight_shortest_first_life    = shortest_life_mp
    @highlight_shortest_first_life_cs = shortest_life_mp ? (shortest_life_mp.survival_times || [])[0].to_i : nil

    # 試合時間: match_timelines.game_end_cs を使用
    timelines_q = MatchTimeline.joins(:match)
                               .includes(match: :event)
                               .where.not(game_end_cs: nil)
    timelines_q = timelines_q.where(matches: { event_id: @filter_events }) if @filter_events.any?

    longest_tl  = timelines_q.order(game_end_cs: :desc).first
    shortest_tl = timelines_q.order(game_end_cs: :asc).first

    @highlight_longest_match    = longest_tl&.match
    @highlight_longest_match_cs = longest_tl&.game_end_cs

    @highlight_shortest_match    = shortest_tl&.match
    @highlight_shortest_match_cs = shortest_tl&.game_end_cs
  end

  def calculate_overall_stats
    # イベントフィルター適用
    base_matches = Match.all
    base_match_players = MatchPlayer.joins(:match).includes(:match, :mobile_suit)

    if @filter_events.any?
      base_matches = base_matches.where(event_id: @filter_events)
      base_match_players = base_match_players.where(matches: { event_id: @filter_events })
    end

    # 全体サマリー
    @overall_total_matches = base_matches.count
    @overall_total_players = base_match_players.distinct.count(:user_id)
    @overall_total_events = @filter_events.any? ? @filter_events.size : Event.joins(:matches).distinct.count

    # 人気機体ランキング（使用回数TOP10）
    suit_usage = base_match_players.group(:mobile_suit_id).count
    @popular_suits = suit_usage.sort_by { |_, count| -count }.first(10).map do |suit_id, count|
      suit = MobileSuit.find(suit_id)
      {
        mobile_suit: suit,
        usage_count: count,
        usage_rate: (@overall_total_matches * 4 > 0 ? (count.to_f / (@overall_total_matches * 4) * 100).round(1) : 0)
      }
    end

    # 高勝率機体ランキング（最低5試合以上、勝率TOP10）
    suit_stats = {}
    base_match_players.find_each do |mp|
      suit_id = mp.mobile_suit_id
      suit_stats[suit_id] ||= { wins: 0, total: 0 }
      suit_stats[suit_id][:total] += 1
      suit_stats[suit_id][:wins] += 1 if mp.match.winning_team == mp.team_number
    end

    @high_winrate_suits = suit_stats
      .select { |_, stats| stats[:total] >= 5 }
      .map do |suit_id, stats|
        {
          mobile_suit: MobileSuit.find(suit_id),
          wins: stats[:wins],
          total: stats[:total],
          win_rate: (stats[:wins].to_f / stats[:total] * 100).round(1)
        }
      end
      .sort_by { |s| -s[:win_rate] }
      .first(10)

    # コスト帯別統計
    cost_stats = {}
    base_match_players.find_each do |mp|
      cost = mp.mobile_suit.cost
      cost_stats[cost] ||= { wins: 0, total: 0 }
      cost_stats[cost][:total] += 1
      cost_stats[cost][:wins] += 1 if mp.match.winning_team == mp.team_number
    end

    total_usage = cost_stats.values.sum { |s| s[:total] }
    @cost_stats = cost_stats.sort_by { |cost, _| -cost }.map do |cost, stats|
      {
        cost: cost,
        usage_count: stats[:total],
        usage_rate: (total_usage > 0 ? (stats[:total].to_f / total_usage * 100).round(1) : 0),
        wins: stats[:wins],
        win_rate: (stats[:total] > 0 ? (stats[:wins].to_f / stats[:total] * 100).round(1) : 0)
      }
    end

    # 環境支配機体ランキング（環境支配度 = 勝率 × 使用回数）
    @dominant_suits = suit_stats
      .map do |suit_id, stats|
        win_rate = stats[:total] > 0 ? (stats[:wins].to_f / stats[:total] * 100).round(1) : 0
        dominance = (win_rate * stats[:total]).round(1)
        {
          mobile_suit: MobileSuit.find(suit_id),
          wins: stats[:wins],
          total: stats[:total],
          win_rate: win_rate,
          dominance: dominance
        }
      end
      .sort_by { |s| -s[:dominance] }
      .first(10)

    # イベント別参加統計
    events_query = Event.joins(:matches)
                        .select("events.*, COUNT(DISTINCT matches.id) as match_count")
                        .group("events.id")
                        .order(held_on: :desc)
                        .limit(10)

    events_query = events_query.where(id: @filter_events) if @filter_events.any?

    @event_stats = events_query.map do |event|
      player_count = MatchPlayer.joins(:match)
                                .where(matches: { event_id: event.id })
                                .distinct
                                .count(:user_id)
      {
        event: event,
        match_count: event.match_count,
        player_count: player_count
      }
    end
  end
end
