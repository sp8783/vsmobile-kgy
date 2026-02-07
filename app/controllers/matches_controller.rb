class MatchesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin, except: [:index, :show]
  before_action :set_event, only: [:new, :create]
  before_action :set_match, only: [:show, :edit, :update, :destroy]

  def index
    @matches = Match.includes(:event, { match_players: [:user, :mobile_suit] }, { reactions: :user }).order(played_at: :desc)

    # フィルター: イベント（複数選択対応）
    if params[:events].present?
      event_ids = params[:events].reject(&:blank?).map(&:to_i)
      @matches = @matches.where(event_id: event_ids) if event_ids.any?
    end

    # フィルター: 参加ユーザー（複数選択対応）
    if params[:users].present?
      user_ids = params[:users].reject(&:blank?).map(&:to_i)
      @matches = @matches.joins(:match_players).where(match_players: { user_id: user_ids }).distinct if user_ids.any?
    end

    # フィルター: 配信台ユーザー（複数選択対応）
    if params[:streaming_users].present?
      streaming_user_ids = params[:streaming_users].reject(&:blank?).map(&:to_i)
      @matches = @matches.joins(:match_players).where(
        match_players: { user_id: streaming_user_ids, team_number: 1, position: 1 }
      ).distinct if streaming_user_ids.any?
    end

    @per_page = [10, 20, 50].include?(params[:per].to_i) ? params[:per].to_i : 20
    @matches = @matches.page(params[:page]).per(@per_page)
    @emojis = MasterEmoji.active.ordered
    @latest_event = Event.order(held_on: :desc).first

    # フィルター用のデータ
    @all_events = Event.order(held_on: :desc)
    @all_users = User.regular_users.order(:nickname)

    # 選択されたフィルター値
    @filter_events = params[:events].present? ? params[:events].reject(&:blank?).map(&:to_i) : []
    @filter_users = params[:users].present? ? params[:users].reject(&:blank?).map(&:to_i) : []
    @filter_streaming_users = params[:streaming_users].present? ? params[:streaming_users].reject(&:blank?).map(&:to_i) : []
  end

  def show
  end

  def new
    @match = @event.matches.build(played_at: Time.current)
    4.times { |i| @match.match_players.build(position: i + 1) }
    @users = User.regular_users.order(:nickname)
    @mobile_suits = MobileSuit.all.order(Arel.sql('position IS NULL, position ASC, cost DESC, name ASC'))
  end

  def create
    @match = @event.matches.build(match_params)
    @match.played_at = Time.current

    if @match.save
      redirect_to @event, notice: "対戦記録を登録しました。"
    else
      @users = User.regular_users.order(:nickname)
      @mobile_suits = MobileSuit.all.order(Arel.sql('position IS NULL, position ASC, cost DESC, name ASC'))
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @users = User.regular_users.order(:nickname)
    @mobile_suits = MobileSuit.all.order(Arel.sql('position IS NULL, position ASC, cost DESC, name ASC'))
  end

  def update
    if @match.update(match_params)
      redirect_to @match, notice: "対戦記録を更新しました。"
    else
      @users = User.regular_users.order(:nickname)
      @mobile_suits = MobileSuit.all.order(Arel.sql('position IS NULL, position ASC, cost DESC, name ASC'))
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
    @match = Match.includes(:event, :match_players => [:user, :mobile_suit]).find(params[:id])
  end

  def match_params
    params.require(:match).permit(:winning_team, :played_at, match_players_attributes: [:id, :user_id, :mobile_suit_id, :team_number, :position])
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
    return rotation.rotation_matches.count - 1
  end
end
