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
    set_global_totals

    # 今日のイベント
    @today_event = Event.where(held_on: Time.zone.today).first
    if @today_event
      @active_rotation = @today_event.rotations.includes(
        rotation_matches: [ :team1_player1, :team1_player2, :team2_player1, :team2_player2, :match ]
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
    @active_rotations = Rotation.where(is_active: true).includes(:event).joins(:event).order("events.held_on DESC")

    # 最近の試合
    @recent_matches = Match.order(played_at: :desc).limit(10).includes(:event, match_players: [ :user, :mobile_suit ])

    # 今後のイベント
    @upcoming_events = Event.where("held_on >= ?", Time.zone.today).order(held_on: :asc).limit(5)

    # 人気機体TOP5
    @popular_mobile_suits = MobileSuit.joins(:match_players)
                                      .select("mobile_suits.*, COUNT(match_players.id) as usage_count")
                                      .group("mobile_suits.id")
                                      .order("usage_count DESC")
                                      .limit(5)

    # イベントごとの試合数
    @event_match_counts = Event.left_joins(:matches)
                               .select("events.*, COUNT(matches.id) as match_count")
                               .group("events.id")
                               .order(held_on: :desc)
                               .limit(10)

    render "admin_dashboard"
  end

  def render_player_dashboard
    set_global_totals

    # 全試合データを一度だけ読み込み（Eager Loading）
    load_all_user_matches

    assign_view_state(
      PlayerDashboardSnapshot.new(user: viewing_as_user, match_players: @all_user_matches).to_h
    )
    assign_view_state(
      PlayerRealtimeStatus.new(user: viewing_as_user).to_h
    )

    # 通知/アラート
    generate_notifications

    @upcoming_events = Event.where("held_on >= ?", Time.zone.today).order(held_on: :asc).limit(3)

    render "index"
  end

  # 全ユーザー試合データを一度だけロード（N+1クエリを防ぐ）
  def load_all_user_matches
    @all_user_matches = viewing_as_user.match_players
                                       .includes(
                                         :mobile_suit,
                                         match: [
                                           :event,
                                           match_players: [ :user, :mobile_suit ]
                                         ]
                                       )
                                       .joins(:match)
                                       .order("matches.played_at DESC, matches.id DESC")
                                       .to_a # 配列にキャッシュ
  end

  def generate_notifications
    @notifications = []

    # 出番が近い通知
    if @user_next_match && @matches_until_user_turn && @matches_until_user_turn <= 2
      @notifications << {
        type: "warning",
        icon: "⚠️",
        message: "もうすぐあなたの出番です！あと#{@matches_until_user_turn}試合"
      }
    end

    # 最大3件まで
    @notifications = @notifications.take(3)
  end

  def set_global_totals
    @total_matches = Match.count
    @total_events = Event.count
    @total_users = User.regular_users.count
  end

  def assign_view_state(attributes)
    attributes.each do |name, value|
      instance_variable_set("@#{name}", value)
    end
  end
end
