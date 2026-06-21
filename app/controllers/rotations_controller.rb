class RotationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin, except: [ :index, :show ]
  before_action :set_rotation, only: [ :show, :edit, :update, :destroy, :activate, :deactivate, :next_match, :record_match, :go_to_match, :update_match_record, :copy_for_next_round ]
  before_action :set_event, only: [ :new, :create ]

  def index
    @rotations = Rotation.includes(:event, :rotation_matches).order(created_at: :desc)
  end

  def show
    assign_view_state(
      RotationShowSnapshot.new(
        rotation: @rotation,
        show_completion_modal: consume_completion_modal_flag
      ).to_h
    )
  end

  def new
    @rotation = @event.rotations.build
    @players = User.regular_users.order(:nickname)
  end

  def create
    @rotation = @event.rotations.build(rotation_params)
    @players = User.regular_users.order(:nickname)

    # Validate player count
    player_ids = params[:player_ids]&.reject(&:blank?) || []
    if player_ids.size < 4
      @rotation.errors.add(:base, "参加プレイヤーは4人以上選択してください（現在#{player_ids.size}人選択）")
      render :new, status: :unprocessable_entity
      return
    elsif player_ids.size > 8
      @rotation.errors.add(:base, "参加プレイヤーは8人以下にしてください（現在#{player_ids.size}人選択）")
      render :new, status: :unprocessable_entity
      return
    end

    if @rotation.save
      result = RotationWorkflowManager.new(rotation: @rotation).generate_matches!(player_ids: player_ids)
      if result.success?
        redirect_to @rotation, notice: "ローテーションを作成しました。"
      else
        @rotation.destroy
        @rotation.errors.add(:base, result.error_message)
        render :new, status: :unprocessable_entity
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @players = User.regular_users.order(:nickname)
  end

  def update
    if @rotation.update(rotation_params)
      redirect_to @rotation, notice: "ローテーションを更新しました。"
    else
      @players = User.regular_users.order(:nickname)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @rotation.destroy
    redirect_to rotations_path, notice: "ローテーションを削除しました。"
  end

  # Activate this rotation
  def activate
    result = RotationWorkflowManager.new(rotation: @rotation).activate!
    redirect_with_result(@rotation, result, success_notice: "ローテーションをアクティブにしました。")
  end

  # Deactivate this rotation
  def deactivate
    result = RotationWorkflowManager.new(rotation: @rotation).deactivate!
    redirect_with_result(@rotation, result, success_notice: "ローテーションを非アクティブにしました。")
  end

  # Move to next match
  def next_match
    result = RotationWorkflowManager.new(rotation: @rotation).next_match!
    redirect_with_result(@rotation, result, success_notice: "次の試合に進みました。")
  end

  # Go to specific match (for skipped matches)
  def go_to_match
    match_index = params[:match_index].to_i
    result = RotationWorkflowManager.new(rotation: @rotation).go_to_match!(match_index: match_index)
    redirect_with_result(@rotation, result, success_notice: "第#{match_index + 1}試合に戻りました。")
  end

  # Record match result
  def record_match
    result = RotationWorkflowManager.new(rotation: @rotation).record_current_match!(
      winning_team: params[:winning_team].to_i,
      suit_ids: rotation_match_suit_ids
    )

    session[:show_completion_modal] = @rotation.id if result.success? && result.completed
    redirect_with_result(@rotation, result, success_notice: "試合を記録しました。")
  end

  # Update existing match record without moving rotation
  def update_match_record
    result = RotationWorkflowManager.new(rotation: @rotation).update_match_record!(
      match_index: params[:match_index].to_i,
      winning_team: params[:winning_team].to_i,
      suit_ids: rotation_match_suit_ids
    )

    redirect_with_result(@rotation, result, success_notice: "試合記録を更新しました。")
  end

  # Copy rotation for next round
  def copy_for_next_round
    result = RotationWorkflowManager.new(rotation: @rotation).copy_for_next_round!
    if result.success?
      redirect_to result.new_rotation, notice: "#{result.new_rotation.round_number}周目のローテーションを作成しました。"
    else
      redirect_to @rotation, alert: result.error_message
    end
  end

  private

  def set_rotation
    @rotation = Rotation.find(params[:id])
  end

  def set_event
    @event = Event.find(params[:event_id])
  end

  def rotation_params
    params.require(:rotation).permit(:round_number)
  end

  def rotation_match_suit_ids
    {
      team1_player1: params[:team1_player1_suit],
      team1_player2: params[:team1_player2_suit],
      team2_player1: params[:team2_player1_suit],
      team2_player2: params[:team2_player2_suit]
    }
  end

  def assign_view_state(attributes)
    attributes.each do |name, value|
      instance_variable_set("@#{name}", value)
    end
  end

  def redirect_with_result(path, result, success_notice:)
    if result.success?
      redirect_to path, notice: success_notice
    else
      redirect_to path, alert: result.error_message
    end
  end

  def consume_completion_modal_flag
    return false unless session[:show_completion_modal] == @rotation.id

    session.delete(:show_completion_modal)
    true
  end
end
