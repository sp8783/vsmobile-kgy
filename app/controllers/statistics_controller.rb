class StatisticsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_filters
  before_action :apply_filters

  def index
    @active_tab = params[:tab] || 'overall'

    # ゲストユーザーは個人統計タブにアクセス不可
    personal_tabs = %w[overview events event_progression mobile_suits opponent_suits partners opponents]
    if current_user.is_guest && personal_tabs.include?(@active_tab)
      redirect_to statistics_path(tab: 'overall'), alert: '個人統計を見るには管理者にアカウント発行を依頼してください'
      return
    end

    case @active_tab
    when 'overview'
      calculate_overview_stats
    when 'overall'
      calculate_overall_stats
    when 'partners'
      calculate_partner_stats
    when 'mobile_suits'
      calculate_mobile_suit_stats
    when 'opponent_suits'
      calculate_mobile_suit_stats
    when 'events'
      calculate_event_stats
    when 'event_progression'
      calculate_event_progression_stats
    when 'opponents'
      calculate_opponent_stats
    end

    # フィルター用のデータ
    @all_events = Event.order(held_on: :desc)
    @all_mobile_suits = MobileSuit.order(:name)
    @all_partners = User.regular_users.where.not(id: viewing_as_user.id).order(:nickname)
  end

  private

  def set_filters
    @filter_events = params[:events].present? ? params[:events].map(&:to_i) : []
    @filter_mobile_suits = params[:mobile_suits].present? ? params[:mobile_suits].map(&:to_i) : []
    @filter_partners = params[:partners].present? ? params[:partners].map(&:to_i) : []
  end

  def apply_filters
    # ログインユーザーの試合を基準に開始
    @filtered_matches = MatchPlayer.where(user_id: viewing_as_user.id)
                                   .joins(:match)
                                   .includes(:match, :mobile_suit, :user)

    # イベントフィルター
    if @filter_events.any?
      @filtered_matches = @filtered_matches.where(matches: { event_id: @filter_events })
    end

    # 機体フィルター（ログインユーザーが使用した機体）
    if @filter_mobile_suits.any?
      @filtered_matches = @filtered_matches.where(mobile_suit_id: @filter_mobile_suits)
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
    all_matches = @filtered_matches.order('matches.played_at ASC').to_a

    max_streak = 0
    current_streak = 0

    all_matches.each do |mp|
      if mp.match.winning_team == mp.team_number
        current_streak += 1
        max_streak = [max_streak, current_streak].max
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

      # パートナーのコストを取得
      partner_mp = match.match_players.find do |mp|
        mp.team_number == my_team && mp.user_id != viewing_as_user.id
      end

      next unless partner_mp

      partner_cost = partner_mp.mobile_suit.cost
      costs = [my_cost, partner_cost].sort.reverse
      cost_key = "#{costs[0]}+#{costs[1]}"

      cost_data[cost_key][:total] += 1
      cost_data[cost_key][:wins] += 1 if match.winning_team == my_team
    end

    cost_data.map do |cost_combo, data|
      costs = cost_combo.split("+").map(&:to_i)
      {
        cost_combo: cost_combo,
        cost1: costs[0],
        cost2: costs[1],
        win_rate: data[:total] > 0 ? (data[:wins].to_f / data[:total] * 100).round(1) : 0,
        total: data[:total]
      }
    end.sort_by { |d| [-d[:cost1], -d[:cost2]] }
  end

  def calculate_rotation_round_stats
    # RotationMatchがある場合のみ計算
    round_data = Hash.new { |h, k| h[k] = { wins: 0, total: 0 } }

    @filtered_matches.each do |my_mp|
      match = my_mp.match

      # rotation_matchがある場合、round_numberを取得
      if match.rotation_match
        round_number = match.rotation_match.round_number

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
        last_used_at: nil
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
      {
        mobile_suit: data[:mobile_suit],
        wins: data[:wins],
        total: data[:total],
        win_rate: data[:total] > 0 ? (data[:wins].to_f / data[:total] * 100).round(1) : 0,
        top_partner_suits: data[:partner_suits].sort_by { |_, count| -count }.take(3).to_h,
        last_used_at: data[:last_used_at]
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
        rotation_name = match.rotation_match.rotation.name

        event_progression_data[event_id][:rotations][rotation_id][:rotation_name] = rotation_name
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
