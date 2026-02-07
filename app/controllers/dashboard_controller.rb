class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # 管理者とプレイヤーで異なるダッシュボードを表示
    if current_user.is_admin? && !viewing_as_someone_else?
      render_admin_dashboard
    else
      render_player_dashboard
    end
  end

  private

  def render_admin_dashboard
    # 基本統計
    @total_matches = Match.count
    @total_events = Event.count
    @total_users = User.regular_users.count

    # 今日のイベント
    @today_event = Event.where(held_on: Time.zone.today).first
    if @today_event
      @active_rotation = @today_event.rotations.includes(
        rotation_matches: [:team1_player1, :team1_player2, :team2_player1, :team2_player2, :match]
      ).find_by(is_active: true)
    end

    # アクティブなローテーションの対戦順情報
    if @active_rotation
      @rotation_matches = @active_rotation.rotation_matches.sort_by(&:match_index)
      @current_rotation_match = @rotation_matches[@active_rotation.current_match_index]
      @upcoming_rotation_matches = @rotation_matches[(@active_rotation.current_match_index + 1)..(@active_rotation.current_match_index + 3)]&.compact || []
    end

    # 最近のイベント
    @recent_events = Event.order(held_on: :desc).limit(5)

    # アクティブなローテーション
    @active_rotations = Rotation.where(is_active: true).includes(:event).joins(:event).order('events.held_on DESC')

    # 最近の試合
    @recent_matches = Match.order(played_at: :desc).limit(10).includes(:event, :match_players => [:user, :mobile_suit])

    # 今後のイベント
    @upcoming_events = Event.where('held_on >= ?', Time.zone.today).order(held_on: :asc).limit(5)

    # 人気機体TOP5
    @popular_mobile_suits = MobileSuit.joins(:match_players)
                                      .select('mobile_suits.*, COUNT(match_players.id) as usage_count')
                                      .group('mobile_suits.id')
                                      .order('usage_count DESC')
                                      .limit(5)

    # イベントごとの試合数
    @event_match_counts = Event.left_joins(:matches)
                               .select('events.*, COUNT(matches.id) as match_count')
                               .group('events.id')
                               .order(held_on: :desc)
                               .limit(10)

    render 'admin_dashboard'
  end

  def render_player_dashboard
    # 基本統計
    @total_matches = Match.count
    @total_events = Event.count
    @total_users = User.regular_users.count

    # 全試合データを一度だけ読み込み（Eager Loading）
    load_all_user_matches

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

    # 最近の試合（キャッシュ済みデータから取得）
    # IDでユニーク化して順序を保つ
    seen_match_ids = Set.new
    @recent_matches = []
    @all_user_matches.each do |mp|
      unless seen_match_ids.include?(mp.match_id)
        seen_match_ids.add(mp.match_id)
        @recent_matches << mp.match
        break if @recent_matches.size >= 5
      end
    end

    # 人気機体TOP5（データベースで集計）
    @popular_mobile_suits = MobileSuit.joins(:match_players)
                                      .select('mobile_suits.*, COUNT(match_players.id) as usage_count')
                                      .group('mobile_suits.id')
                                      .order('usage_count DESC')
                                      .limit(5)

    # ユーザーのお気に入り機体（キャッシュ済みデータから集計）
    user_suit_usage = Hash.new(0)
    @all_user_matches.each { |mp| user_suit_usage[mp.mobile_suit] += 1 }
    @user_favorite_suits = user_suit_usage.sort_by { |_, count| -count }
                                          .take(3)
                                          .map { |suit, count| suit.tap { |s| s.define_singleton_method(:usage_count) { count } } }

    @upcoming_events = Event.where('held_on >= ?', Time.zone.today).order(held_on: :asc).limit(3)
    @latest_event = Event.order(held_on: :desc).first

    render 'index'
  end

  # 全ユーザー試合データを一度だけロード（N+1クエリを防ぐ）
  def load_all_user_matches
    @all_user_matches = viewing_as_user.match_players
                                       .includes(
                                         :mobile_suit,
                                         match: [
                                           :event,
                                           match_players: [:user, :mobile_suit]
                                         ]
                                       )
                                       .joins(:match)
                                       .order('matches.played_at DESC, matches.id DESC')
                                       .to_a # 配列にキャッシュ
  end

  def calculate_personal_stats
    @user_total_matches = viewing_as_user.match_players.count
    @user_wins = viewing_as_user.match_players.joins(:match).where(
      "(matches.winning_team = 1 AND match_players.team_number = 1) OR (matches.winning_team = 2 AND match_players.team_number = 2)"
    ).count
    @user_win_rate = @user_total_matches > 0 ? (@user_wins.to_f / @user_total_matches * 100).round(1) : 0
  end

  def calculate_realtime_status
    # 今日のイベントを取得
    @today_event = Event.where(held_on: Time.zone.today).first
    return unless @today_event

    # 今日のイベントのアクティブなローテーション表を取得（rotation_matchesを事前ロード）
    @active_rotation = @today_event.rotations.includes(
      rotation_matches: [:team1_player1, :team1_player2, :team2_player1, :team2_player2]
    ).find_by(is_active: true)
    return unless @active_rotation

    # ローテーション表から情報を取得（既にロード済み）
    @rotation_matches = @active_rotation.rotation_matches.sort_by(&:match_index)
    @rotation_total_matches = @rotation_matches.size
    @rotation_current_match_index = @active_rotation.current_match_index
    @current_rotation_match = @rotation_matches[@rotation_current_match_index]

    # 現在のユーザーの次の試合を取得（メモリ内で検索）
    @user_next_rotation_match = @active_rotation.rotation_matches.find do |rm|
      rm.match_index >= @active_rotation.current_match_index &&
      (rm.team1_player1_id == viewing_as_user.id ||
       rm.team1_player2_id == viewing_as_user.id ||
       rm.team2_player1_id == viewing_as_user.id ||
       rm.team2_player2_id == viewing_as_user.id)
    end

    if @user_next_rotation_match
      @matches_until_user_turn = @user_next_rotation_match.match_index - @active_rotation.current_match_index
      @match_info = @active_rotation.match_info_for_player(@user_next_rotation_match, viewing_as_user.id)
      @user_partner = @match_info[:partner]
      @opponent_players = @match_info[:opponents]

      # 配信担当かどうか
      @is_streaming = (@user_next_rotation_match.team1_player1_id == viewing_as_user.id)
    end
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

    # 最大3件まで
    @notifications = @notifications.take(3)
  end

  def calculate_condition_meter
    # キャッシュ済みデータを使用して、ユニークな試合のみを取得
    seen_match_ids = Set.new
    recent_match_players = []
    @all_user_matches.each do |mp|
      unless seen_match_ids.include?(mp.match_id)
        seen_match_ids.add(mp.match_id)
        recent_match_players << mp
        break if recent_match_players.size >= 10
      end
    end

    # 直近5試合の勝敗を計算（新しい順）
    @recent_5_results = recent_match_players.take(5).map do |mp|
      mp.match.winning_team == mp.team_number
    end

    # 直近10試合の勝率
    recent_10_results = recent_match_players.map do |mp|
      mp.match.winning_team == mp.team_number
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
    # 全試合データを使用して正確にカウント
    @current_streak = 0
    @streak_type = nil
    streak_seen_match_ids = Set.new

    @all_user_matches.each do |mp|
      next if streak_seen_match_ids.include?(mp.match_id)
      streak_seen_match_ids.add(mp.match_id)

      is_win = mp.match.winning_team == mp.team_number

      if @streak_type.nil?
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
    # キャッシュ済みデータを使用してパートナーごとに集計
    partners_stats = {}

    @all_user_matches.each do |my_mp|
      match = my_mp.match
      my_team = my_mp.team_number

      # 同じチームのパートナーを見つける（既にincludesで読み込み済み）
      # .to_aで配列化してメモリ内で検索
      partner_mp = match.match_players.to_a.find { |mp| mp.team_number == my_team && mp.user_id != viewing_as_user.id }
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
    target_event = Event.where(held_on: Time.zone.today).first || Event.order(held_on: :desc).first

    return unless target_event

    # キャッシュ済みデータから該当イベントの試合をフィルタ
    event_matches = @all_user_matches.select { |mp| mp.match.event_id == target_event.id }

    suit_stats = {}

    event_matches.each do |mp|
      suit_id = mp.mobile_suit_id
      suit_stats[suit_id] ||= {
        mobile_suit: mp.mobile_suit,
        usage: 0,
        wins: 0
      }

      suit_stats[suit_id][:usage] += 1

      is_win = (mp.match.winning_team == mp.team_number)
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
    @is_today_event = (target_event.held_on == Time.zone.today)
  end

  def calculate_event_comparison
    # 直近3イベント
    recent_events = Event.order(held_on: :desc).limit(3)

    @event_comparison = recent_events.map do |event|
      # キャッシュ済みデータから該当イベントの試合をフィルタ
      event_matches = @all_user_matches.select { |mp| mp.match.event_id == event.id }

      total = event_matches.size
      wins = event_matches.count { |mp| mp.match.winning_team == mp.team_number }

      {
        event: event,
        total: total,
        wins: wins,
        losses: total - wins,
        win_rate: total > 0 ? (wins.to_f / total * 100).round(1) : 0,
        is_today: event.held_on == Time.zone.today
      }
    end
  end

  def calculate_cost_analysis
    # キャッシュ済みデータを使用してコスト組み合わせを集計
    cost_stats = Hash.new { |h, k| h[k] = { wins: 0, total: 0 } }

    @all_user_matches.each do |my_mp|
      match = my_mp.match
      my_team = my_mp.team_number
      my_cost = my_mp.mobile_suit.cost

      # パートナーのコストを取得（既にincludesで読み込み済み）
      # .to_aで配列化してメモリ内で検索
      partner_mp = match.match_players.to_a.find { |mp| mp.team_number == my_team && mp.user_id != viewing_as_user.id }
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
    # キャッシュ済みデータから使用頻度TOP3の機体を集計
    suit_usage = Hash.new(0)
    @all_user_matches.each { |mp| suit_usage[mp.mobile_suit_id] += 1 }
    top_suits = suit_usage.sort_by { |_, count| -count }.take(3).map { |suit_id, _| suit_id }

    @matchup_matrix = []

    top_suits.each do |my_suit_id|
      # この機体を使った試合をフィルタ
      my_matches = @all_user_matches.select { |mp| mp.mobile_suit_id == my_suit_id }
      next if my_matches.empty?

      my_suit = my_matches.first.mobile_suit

      # 対戦相手の機体ごとに勝率を計算
      opponent_stats = Hash.new { |h, k| h[k] = { wins: 0, total: 0, mobile_suit: nil } }

      my_matches.each do |my_mp|
        match = my_mp.match
        my_team = my_mp.team_number
        opponent_team = my_team == 1 ? 2 : 1

        # 相手チームの機体を取得（既にincludesで読み込み済み）
        # .to_aで配列化してメモリ内で検索
        match.match_players.to_a.each do |opp_mp|
          next unless opp_mp.team_number == opponent_team

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
