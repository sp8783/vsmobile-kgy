class MatchesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin, except: [ :index, :show ]
  before_action :set_event, only: [ :new, :create ]
  before_action :set_match, only: [ :show, :edit, :update, :destroy ]

  def index
    sort = params[:sort].presence_in(%w[latest reactions]) || "latest"
    @sort = sort

    base_scope = sort == "reactions" ? Match.by_reactions : Match.by_latest
    @matches = base_scope.includes(:event, { match_players: [ :user, :mobile_suit ] }, { reactions: :user })

    # フィルター: イベント（複数選択対応）
    if params[:events].present?
      event_ids = params[:events].reject(&:blank?).map(&:to_i)
      @matches = @matches.where(event_id: event_ids) if event_ids.any?
    end

    # フィルター: 参加ユーザー（複数選択対応）
    if params[:users].present?
      user_ids = params[:users].reject(&:blank?).map(&:to_i)
      if user_ids.any?
        if params[:users_mode] == "and"
          user_ids.each do |uid|
            @matches = @matches.where(
              "EXISTS (SELECT 1 FROM match_players mp WHERE mp.match_id = matches.id AND mp.user_id = ?)", uid
            )
          end
        else
          @matches = @matches.joins(:match_players).where(match_players: { user_id: user_ids }).distinct
        end
      end
    end

    # フィルター: 配信台ユーザー（複数選択対応）
    if params[:streaming_users].present?
      streaming_user_ids = params[:streaming_users].reject(&:blank?).map(&:to_i)
      if streaming_user_ids.any?
        if params[:streaming_users_mode] == "and"
          streaming_user_ids.each do |uid|
            @matches = @matches.where(
              "EXISTS (SELECT 1 FROM match_players mp WHERE mp.match_id = matches.id AND mp.user_id = ? AND mp.team_number = 1 AND mp.position = 1)", uid
            )
          end
        else
          @matches = @matches.joins(:match_players).where(
            match_players: { user_id: streaming_user_ids, team_number: 1, position: 1 }
          ).distinct
        end
      end
    end

    # フィルター: 使用機体（複数選択対応）
    if params[:mobile_suits].present?
      mobile_suit_ids = params[:mobile_suits].reject(&:blank?).map(&:to_i)
      if mobile_suit_ids.any?
        @matches = @matches.joins(:match_players).where(match_players: { mobile_suit_id: mobile_suit_ids }).distinct
      end
    end

    # フィルター: コスト（複数選択対応）
    if params[:costs].present?
      cost_values = params[:costs].reject(&:blank?).map(&:to_i)
      if cost_values.any?
        @matches = @matches.joins(match_players: :mobile_suit).where(mobile_suits: { cost: cost_values }).distinct
      end
    end

    # 統計条件フィルター共通: 対象プレイヤー
    stat_player_id = params[:stat_player_id].present? ? params[:stat_player_id].to_i : nil

    # フィルター: OL条件（排他選択）
    ol_filter = params[:ol_filter].presence_in(%w[ol_unused_win ol_unused_loss])
    case ol_filter
    when "ol_unused_win"
      # 勝利チームがOL未発動だった試合
      scope = @matches.where(
        "(winning_team = 1 AND team1_ex_overlimit_before_end = TRUE) OR " \
        "(winning_team = 2 AND team2_ex_overlimit_before_end = TRUE)"
      )
      if stat_player_id
        scope = scope.joins(:match_players).where(
          "match_players.user_id = ? AND match_players.team_number = matches.winning_team",
          stat_player_id
        )
        @matches = scope.distinct
      else
        @matches = scope
      end
    when "ol_unused_loss"
      # 敗北チームがOL未発動だった試合
      scope = @matches.where(
        "(winning_team = 1 AND team2_ex_overlimit_before_end = TRUE) OR " \
        "(winning_team = 2 AND team1_ex_overlimit_before_end = TRUE)"
      )
      if stat_player_id
        scope = scope.joins(:match_players).where(
          "match_players.user_id = ? AND match_players.team_number != matches.winning_team",
          stat_player_id
        )
        @matches = scope.distinct
      else
        @matches = scope
      end
    end

    # フィルター: EX条件（チェックボックス）
    stat_filters = Array(params[:stat_filters]).reject(&:blank?)

    if stat_filters.include?("ex_leftover_loss")
      scope = @matches.joins(:match_players).where(
        "match_players.team_number != matches.winning_team AND " \
        "(match_players.last_death_ex_available = TRUE OR match_players.survive_loss_ex_available = TRUE)"
      )
      scope = scope.where(match_players: { user_id: stat_player_id }) if stat_player_id
      @matches = scope.distinct
    end

    if stat_filters.include?("ex_leftover_win")
      # 敗北チームにEXバースト残しプレイヤーがいる試合（= 勝利チームがEXを残させた試合）
      scope = @matches.where(
        "EXISTS (SELECT 1 FROM match_players mp WHERE mp.match_id = matches.id " \
        "AND mp.team_number != matches.winning_team " \
        "AND (mp.last_death_ex_available = TRUE OR mp.survive_loss_ex_available = TRUE))"
      )
      if stat_player_id
        scope = scope.joins(:match_players).where(
          "match_players.user_id = ? AND match_players.team_number = matches.winning_team",
          stat_player_id
        )
        @matches = scope.distinct
      else
        @matches = scope
      end
    end

    if stat_filters.include?("exburst_death")
      scope = @matches.joins(:match_players).where("match_players.exburst_deaths > 0")
      scope = scope.where(match_players: { user_id: stat_player_id }) if stat_player_id
      @matches = scope.distinct
    end

    # フィルター: ダメージ閾値（以上/以下切り替え対応）
    if params[:damage_dealt_val].present?
      dealt_val = params[:damage_dealt_val].to_i
      dealt_op = params[:damage_dealt_dir] == "lte" ? "<=" : ">="
      scope = @matches.joins(:match_players).where("match_players.damage_dealt #{dealt_op} ?", dealt_val)
      scope = scope.where(match_players: { user_id: stat_player_id }) if stat_player_id
      @matches = scope.distinct
    end

    if params[:damage_received_val].present?
      received_val = params[:damage_received_val].to_i
      received_op = params[:damage_received_dir] == "lte" ? "<=" : ">="
      scope = @matches.joins(:match_players).where("match_players.damage_received #{received_op} ?", received_val)
      scope = scope.where(match_players: { user_id: stat_player_id }) if stat_player_id
      @matches = scope.distinct
    end

    @per_page = [ 10, 20, 50 ].include?(params[:per].to_i) ? params[:per].to_i : 20
    @matches = @matches.page(params[:page]).per(@per_page)
    @emojis = MasterEmoji.active.ordered
    @latest_event = Event.order(held_on: :desc).first

    # フィルター用のデータ
    @all_events = Event.order(held_on: :desc)
    @all_users = User.regular_users.order(:nickname)
    @all_mobile_suits = MobileSuit.all.order(Arel.sql("position IS NULL, position ASC, cost DESC, name ASC"))

    # 選択されたフィルター値
    @filter_events = params[:events].present? ? params[:events].reject(&:blank?).map(&:to_i) : []
    @filter_users = params[:users].present? ? params[:users].reject(&:blank?).map(&:to_i) : []
    @filter_users_mode = params[:users_mode].presence_in(%w[or and]) || "or"
    @filter_streaming_users = params[:streaming_users].present? ? params[:streaming_users].reject(&:blank?).map(&:to_i) : []
    @filter_streaming_users_mode = params[:streaming_users_mode].presence_in(%w[or and]) || "or"
    @filter_mobile_suits = params[:mobile_suits].present? ? params[:mobile_suits].reject(&:blank?).map(&:to_i) : []
    @filter_costs = params[:costs].present? ? params[:costs].reject(&:blank?).map(&:to_i) : []
    @filter_stat_player_id = stat_player_id
    @filter_ol_filter = ol_filter
    @filter_stat_filters = stat_filters
    @filter_damage_dealt_val = params[:damage_dealt_val].presence
    @filter_damage_dealt_dir = params[:damage_dealt_dir].presence_in(%w[gte lte]) || "gte"
    @filter_damage_received_val = params[:damage_received_val].presence
    @filter_damage_received_dir = params[:damage_received_dir].presence_in(%w[gte lte]) || "gte"
  end

  def show
  end

  def new
    @match = @event.matches.build(played_at: Time.current)
    4.times { |i| @match.match_players.build(position: i + 1) }
    @users = User.regular_users.order(:nickname)
    @mobile_suits = MobileSuit.all.order(Arel.sql("position IS NULL, position ASC, cost DESC, name ASC"))
  end

  def create
    @match = @event.matches.build(match_params)
    @match.played_at = Time.current

    if @match.save
      redirect_to @event, notice: "対戦記録を登録しました。"
    else
      @users = User.regular_users.order(:nickname)
      @mobile_suits = MobileSuit.all.order(Arel.sql("position IS NULL, position ASC, cost DESC, name ASC"))
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @users = User.regular_users.order(:nickname)
    @mobile_suits = MobileSuit.all.order(Arel.sql("position IS NULL, position ASC, cost DESC, name ASC"))
  end

  def update
    if @match.update(match_params)
      redirect_to @match, notice: "対戦記録を更新しました。"
    else
      @users = User.regular_users.order(:nickname)
      @mobile_suits = MobileSuit.all.order(Arel.sql("position IS NULL, position ASC, cost DESC, name ASC"))
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    event = @match.event
    rotation_match = RotationMatch.find_by(match_id: @match.id)

    ActiveRecord::Base.transaction do
      # rotation_matchesの参照を解除
      RotationMatch.where(match_id: @match.id).update_all(match_id: nil)

      # 試合を削除
      @match.destroy

      # ローテーションがある場合、current_match_indexを更新
      if rotation_match && rotation_match.rotation
        rotation = rotation_match.rotation
        next_unrecorded_index = find_next_unrecorded_match_index(rotation)
        if next_unrecorded_index
          rotation.update!(current_match_index: next_unrecorded_index)
        end
      end
    end

    # ローテーションページから削除した場合はローテーションページに戻る
    if rotation_match && rotation_match.rotation
      redirect_to rotation_path(rotation_match.rotation), notice: "対戦記録を削除しました。"
    else
      redirect_to event_path(event), notice: "対戦記録を削除しました。"
    end
  rescue => e
    if rotation_match && rotation_match.rotation
      redirect_to rotation_path(rotation_match.rotation), alert: "削除に失敗しました: #{e.message}"
    else
      redirect_to event_path(event), alert: "削除に失敗しました: #{e.message}"
    end
  end

  def bulk_destroy
    match_ids = params[:match_ids] || []

    if match_ids.empty?
      redirect_to matches_path, alert: "削除する試合を選択してください。"
      return
    end

    # rotation_matchesの参照を解除してから削除
    ActiveRecord::Base.transaction do
      # 影響を受けるローテーションを取得
      affected_rotations = RotationMatch.where(match_id: match_ids).includes(:rotation).map(&:rotation).compact.uniq

      # rotation_matchesのmatch_idをnullに設定
      RotationMatch.where(match_id: match_ids).update_all(match_id: nil)

      # 試合を削除
      deleted_count = Match.where(id: match_ids).destroy_all.count

      # 影響を受けた各ローテーションのcurrent_match_indexを更新
      affected_rotations.each do |rotation|
        next_unrecorded_index = find_next_unrecorded_match_index(rotation)
        if next_unrecorded_index
          rotation.update!(current_match_index: next_unrecorded_index)
        end
      end

      redirect_to matches_path, notice: "#{deleted_count}件の対戦記録を削除しました。"
    end
  rescue => e
    redirect_to matches_path, alert: "削除に失敗しました: #{e.message}"
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_match
    @match = Match.includes(:event, :match_timeline, match_players: [ :user, :mobile_suit ]).find(params[:id])
  end

  def match_params
    params.require(:match).permit(:winning_team, :played_at, :video_timestamp_text, match_players_attributes: [ :id, :user_id, :mobile_suit_id, :team_number, :position ])
  end

  # Find the next unrecorded match starting from current position
  def find_next_unrecorded_match_index(rotation)
    rotation_matches = rotation.rotation_matches.includes(:match).order(:match_index)

    # Start searching from the current match index
    rotation_matches.each do |rm|
      if rm.match_index > rotation.current_match_index && rm.match.nil?
        return rm.match_index
      end
    end

    # If no unrecorded match found after current position, check from the beginning
    rotation_matches.each do |rm|
      if rm.match.nil?
        return rm.match_index
      end
    end

    # All matches are recorded, stay at the last match
    rotation.rotation_matches.count - 1
  end
end
