class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # 基本統計
    @total_matches = Match.count
    @total_events = Event.count
    @total_users = User.count

    # 個人統計
    calculate_personal_stats

    # リアルタイム待機状況（今日のイベント）
    calculate_realtime_status

    # 通知/アラート
    generate_notifications

    # 調子メーター
    calculate_condition_meter

    # ベストパートナー
    calculate_best_partners

    # 機体使用トレンド（直近のイベント）
    calculate_event_mobile_suit_trend

    # 対戦会クイック比較
    calculate_event_comparison

    # コスト帯分析
    calculate_cost_analysis

    # 対面相性マトリクス
    calculate_matchup_matrix

    # 既存機能（ログインユーザーが参加した試合のみ）
    # ログインユーザーが参加した試合のIDを新しい順で取得
    user_match_ids = MatchPlayer.where(user_id: viewing_as_user.id)
                                 .joins(:match)
                                 .order('matches.played_at DESC')
                                 .limit(5)
                                 .pluck(:match_id)
                                 .uniq

    # 取得したIDの試合を取得し、IDの順序を維持してソート
    @recent_matches = Match.where(id: user_match_ids)
                           .includes(:event, :match_players => [:user, :mobile_suit])
                           .sort_by { |match| user_match_ids.index(match.id) }

    @popular_mobile_suits = MobileSuit.joins(:match_players)
                                      .select('mobile_suits.*, COUNT(match_players.id) as usage_count')
                                      .group('mobile_suits.id')
                                      .order('usage_count DESC')
                                      .limit(5)

    @user_favorite_suits = viewing_as_user.match_players
                                       .joins(:mobile_suit)
                                       .select('mobile_suits.*, COUNT(match_players.id) as usage_count')
                                       .group('mobile_suits.id')
                                       .order('usage_count DESC')
                                       .limit(3)

    @upcoming_events = Event.where('held_on >= ?', Date.today).order(held_on: :asc).limit(3)
    @latest_event = Event.order(held_on: :desc).first
  end

  private

  def calculate_personal_stats
    @user_total_matches = viewing_as_user.match_players.count
    @user_wins = viewing_as_user.match_players.joins(:match).where(
      "(matches.winning_team = 1 AND match_players.team_number = 1) OR (matches.winning_team = 2 AND match_players.team_number = 2)"
    ).count
    @user_win_rate = @user_total_matches > 0 ? (@user_wins.to_f / @user_total_matches * 100).round(1) : 0
  end

  def calculate_realtime_status
    # 今日のイベントを取得
    @today_event = Event.where(held_on: Date.today).first
    return unless @today_event

    # イベントの全試合
    all_matches = @today_event.matches.order(played_at: :asc)
    @event_total_matches = all_matches.count
    @event_completed_matches = all_matches.count # 実際は完了した試合のみカウント

    # ユーザーが参加する試合
    user_matches = all_matches.joins(:match_players).where(match_players: { user_id: viewing_as_user.id })
    @user_next_match = user_matches.first

    if @user_next_match
      # ユーザーの出番までの試合数を計算
      @matches_until_user_turn = all_matches.where('played_at < ?', @user_next_match.played_at).count

      # パートナーを取得
      partner_player = @user_next_match.match_players
                                       .where(team_number: viewing_as_user.match_players
                                                                       .find_by(match_id: @user_next_match.id).team_number)
                                       .where.not(user_id: viewing_as_user.id)
                                       .first
      @user_partner = partner_player&.user

      # 対戦相手チームを取得
      user_team = viewing_as_user.match_players.find_by(match_id: @user_next_match.id).team_number
      opponent_team = user_team == 1 ? 2 : 1
      @opponent_players = @user_next_match.match_players.where(team_number: opponent_team)
    end

    # 現在進行中の試合（最新の試合）
    @current_match = all_matches.first
  end

  def generate_notifications
    @notifications = []

    # 出番が近い通知
    if @user_next_match && @matches_until_user_turn && @matches_until_user_turn <= 2
      @notifications << {
        type: 'warning',
        icon: '⚠️',
        message: "もうすぐあなたの出番です！あと#{@matches_until_user_turn}試合"
      }
    end

    # 連勝通知
    recent_matches = viewing_as_user.match_players
                                 .joins(:match)
                                 .order('matches.played_at DESC')
                                 .limit(10)

    winning_streak = 0
    recent_matches.each do |mp|
      match = mp.match
      is_win = (match.winning_team == 1 && mp.team_number == 1) ||
               (match.winning_team == 2 && mp.team_number == 2)
      if is_win
        winning_streak += 1
      else
        break
      end
    end

    if winning_streak >= 3
      @notifications << {
        type: 'success',
        icon: '🔥',
        message: "#{winning_streak}連勝中！調子が良いですね！"
      }
    end

    # 最大3件まで
    @notifications = @notifications.take(3)
  end

  def calculate_condition_meter
    # ログインユーザーの試合を新しい順で取得
    user_match_players = MatchPlayer.where(user_id: viewing_as_user.id)
                                    .joins(:match)
                                    .order('matches.played_at DESC')
                                    .includes(:match)

    # 直近5試合の勝敗を計算（新しい順）
    @recent_5_results = []
    user_match_players.limit(5).each do |mp|
      is_win = (mp.match.winning_team == mp.team_number)
      @recent_5_results << is_win
    end

    # 直近10試合の勝率
    recent_10_results = []
    user_match_players.limit(10).each do |mp|
      is_win = (mp.match.winning_team == mp.team_number)
      recent_10_results << is_win
    end

    if recent_10_results.any?
      recent_10_wins = recent_10_results.count(true)
      @recent_10_win_rate = (recent_10_wins.to_f / recent_10_results.count * 100).round(1)
      @recent_10_diff = @recent_10_win_rate - @user_win_rate
    else
      @recent_10_win_rate = 0
      @recent_10_diff = 0
    end

    # 連勝/連敗状況（最新の試合から順番にカウント）
    @current_streak = 0
    @streak_type = nil

    # 直近5試合の結果を使って連勝/連敗をカウント
    @recent_5_results.each_with_index do |is_win, index|
      if index == 0
        # 最新の試合で連勝/連敗のタイプを決定
        @streak_type = is_win ? 'win' : 'lose'
        @current_streak = 1
      elsif (@streak_type == 'win' && is_win) || (@streak_type == 'lose' && !is_win)
        # 連勝/連敗が続いている
        @current_streak += 1
      else
        # 連勝/連敗が途切れた
        break
      end
    end
  end

  def calculate_best_partners
    # 自分が参加した試合のパートナーごとに勝率を計算
    partners_stats = {}

    viewing_as_user.match_players.includes(:match, :mobile_suit).each do |my_mp|
      match = my_mp.match
      my_team = my_mp.team_number

      # 同じチームのパートナーを見つける
      partner_mp = match.match_players.where(team_number: my_team).where.not(user_id: viewing_as_user.id).first
      next unless partner_mp

      partner_id = partner_mp.user_id
      partners_stats[partner_id] ||= {
        user: partner_mp.user,
        wins: 0,
        total: 0,
        suit_combinations: Hash.new(0)
      }

      # 勝敗判定
      is_win = (match.winning_team == my_team)
      partners_stats[partner_id][:wins] += 1 if is_win
      partners_stats[partner_id][:total] += 1

      # 機体の組み合わせを記録
      combo_key = "#{my_mp.mobile_suit.name} & #{partner_mp.mobile_suit.name}"
      partners_stats[partner_id][:suit_combinations][combo_key] += 1
    end

    # 3試合以上のパートナーのみフィルタリングして勝率でソート
    @best_partners = partners_stats
                      .select { |_, stats| stats[:total] >= 3 }
                      .map do |partner_id, stats|
                        {
                          user: stats[:user],
                          win_rate: (stats[:wins].to_f / stats[:total] * 100).round(1),
                          wins: stats[:wins],
                          total: stats[:total],
                          best_combo: stats[:suit_combinations].max_by { |_, count| count }&.first
                        }
                      end
                      .sort_by { |p| -p[:win_rate] }
                      .take(3)
  end

  def calculate_event_mobile_suit_trend
    # 対象イベントを決定（今日のイベントがあればそれ、なければ直近のイベント）
    target_event = Event.where(held_on: Date.today).first || Event.order(held_on: :desc).first

    return unless target_event

    # 対象イベントでの試合で使用した機体を集計
    event_matches = viewing_as_user.match_players
                                .joins(:match)
                                .where(matches: { event_id: target_event.id })

    suit_stats = {}

    event_matches.each do |mp|
      suit_id = mp.mobile_suit_id
      suit_stats[suit_id] ||= {
        mobile_suit: mp.mobile_suit,
        usage: 0,
        wins: 0
      }

      suit_stats[suit_id][:usage] += 1

      match = mp.match
      is_win = (match.winning_team == mp.team_number)
      suit_stats[suit_id][:wins] += 1 if is_win
    end

    @event_suit_trend = suit_stats.map do |suit_id, stats|
      win_rate = stats[:usage] > 0 ? (stats[:wins].to_f / stats[:usage] * 100).round(1) : 0
      {
        mobile_suit: stats[:mobile_suit],
        usage: stats[:usage],
        win_rate: win_rate,
        recommended: win_rate >= 60
      }
    end.sort_by { |s| -s[:usage] }

    @trend_event = target_event
    @is_today_event = (target_event.held_on == Date.today)
  end

  def calculate_event_comparison
    # 直近3イベント
    recent_events = Event.order(held_on: :desc).limit(3)

    @event_comparison = recent_events.map do |event|
      # このイベントでの自分の試合
      event_matches = viewing_as_user.match_players
                                  .joins(:match)
                                  .where(matches: { event_id: event.id })

      total = event_matches.count
      wins = event_matches.count do |mp|
        match = mp.match
        (match.winning_team == 1 && mp.team_number == 1) ||
        (match.winning_team == 2 && mp.team_number == 2)
      end

      {
        event: event,
        total: total,
        wins: wins,
        losses: total - wins,
        win_rate: total > 0 ? (wins.to_f / total * 100).round(1) : 0,
        is_today: event.held_on == Date.today
      }
    end
  end

  def calculate_cost_analysis
    # コスト組み合わせごとに勝率を計算
    cost_stats = Hash.new { |h, k| h[k] = { wins: 0, total: 0 } }

    viewing_as_user.match_players.includes(:match, :mobile_suit).each do |my_mp|
      match = my_mp.match
      my_team = my_mp.team_number
      my_cost = my_mp.mobile_suit.cost

      # パートナーのコストを取得
      partner_mp = match.match_players.where(team_number: my_team).where.not(user_id: viewing_as_user.id).first
      next unless partner_mp

      partner_cost = partner_mp.mobile_suit.cost

      # コスト組み合わせのキー（小さい方を先に）
      costs = [my_cost, partner_cost].sort.reverse
      cost_key = "#{costs[0]}+#{costs[1]}"

      cost_stats[cost_key][:total] += 1

      is_win = (match.winning_team == my_team)
      cost_stats[cost_key][:wins] += 1 if is_win
    end

    # 3試合以上の組み合わせのみ表示
    @cost_analysis = cost_stats
                      .select { |_, stats| stats[:total] >= 3 }
                      .map do |cost_key, stats|
                        win_rate = (stats[:wins].to_f / stats[:total] * 100).round(1)
                        {
                          cost_combo: cost_key,
                          wins: stats[:wins],
                          total: stats[:total],
                          losses: stats[:total] - stats[:wins],
                          win_rate: win_rate,
                          judgment: win_rate >= 60 ? '得意' : (win_rate >= 40 ? '普通' : '苦手')
                        }
                      end
                      .sort_by { |c| -c[:win_rate] }
  end

  def calculate_matchup_matrix
    # 自分のよく使う機体TOP3
    top_suits = viewing_as_user.match_players
                            .select('mobile_suit_id, COUNT(*) as usage_count')
                            .group(:mobile_suit_id)
                            .order('usage_count DESC')
                            .limit(3)
                            .map(&:mobile_suit_id)

    @matchup_matrix = []

    top_suits.each do |my_suit_id|
      my_suit = MobileSuit.find(my_suit_id)

      # この機体を使った試合
      my_matches = viewing_as_user.match_players.where(mobile_suit_id: my_suit_id)

      # 対戦相手の機体ごとに勝率を計算
      opponent_stats = Hash.new { |h, k| h[k] = { wins: 0, total: 0, mobile_suit: nil } }

      my_matches.each do |my_mp|
        match = my_mp.match
        my_team = my_mp.team_number
        opponent_team = my_team == 1 ? 2 : 1

        # 相手チームの機体を取得
        match.match_players.where(team_number: opponent_team).each do |opp_mp|
          opp_suit_id = opp_mp.mobile_suit_id
          opponent_stats[opp_suit_id][:mobile_suit] = opp_mp.mobile_suit
          opponent_stats[opp_suit_id][:total] += 1

          is_win = (match.winning_team == my_team)
          opponent_stats[opp_suit_id][:wins] += 1 if is_win
        end
      end

      # 2試合以上対戦した機体のみ
      matchups = opponent_stats
                  .select { |_, stats| stats[:total] >= 2 }
                  .map do |opp_suit_id, stats|
                    win_rate = (stats[:wins].to_f / stats[:total] * 100).round(1)
                    {
                      opponent_suit: stats[:mobile_suit],
                      wins: stats[:wins],
                      total: stats[:total],
                      losses: stats[:total] - stats[:wins],
                      win_rate: win_rate,
                      compatibility: win_rate >= 60 ? '得意' : (win_rate >= 40 ? '普通' : '苦手')
                    }
                  end
                  .sort_by { |m| -m[:win_rate] }
                  .take(5)

      @matchup_matrix << {
        my_suit: my_suit,
        matchups: matchups
      } if matchups.any?
    end
  end
end
