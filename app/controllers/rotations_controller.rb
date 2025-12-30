class RotationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_rotation, only: [:show, :edit, :update, :destroy, :activate, :next_match, :record_match, :player_view]
  before_action :set_event, only: [:new, :create]

  def index
    @rotations = Rotation.includes(:event).order(created_at: :desc)
  end

  def show
    @rotation_matches = @rotation.rotation_matches
                                  .includes(:team1_player1, :team1_player2, :team2_player1, :team2_player2, :match)
                                  .order(:match_index)
    @current_match = @rotation_matches[@rotation.current_match_index]
    @player_statistics = @rotation.player_statistics
  end

  def new
    @rotation = @event.rotations.build
    @players = User.where.not(is_admin: true).order(:nickname)
  end

  def create
    @rotation = @event.rotations.build(rotation_params)
    @players = User.where.not(is_admin: true).order(:nickname)

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
      # Generate rotation matches
      generate_rotation_matches(@rotation, player_ids)
      redirect_to @rotation, notice: 'ローテーションを作成しました。'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @players = User.where.not(is_admin: true).order(:nickname)
  end

  def update
    if @rotation.update(rotation_params)
      redirect_to @rotation, notice: 'ローテーションを更新しました。'
    else
      @players = User.where.not(is_admin: true).order(:nickname)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @rotation.destroy
    redirect_to rotations_path, notice: 'ローテーションを削除しました。'
  end

  # Activate this rotation
  def activate
    # Deactivate all rotations for this event
    @rotation.event.rotations.update_all(is_active: false)

    # Activate this rotation
    @rotation.update(is_active: true)
    redirect_to @rotation, notice: 'ローテーションをアクティブにしました。'
  end

  # Move to next match
  def next_match
    if @rotation.current_match_index < @rotation.rotation_matches.count - 1
      @rotation.increment!(:current_match_index)
      redirect_to @rotation, notice: '次の試合に進みました。'
    else
      redirect_to @rotation, alert: 'これが最後の試合です。'
    end
  end

  # Record match result
  def record_match
    Rails.logger.info "=== Record Match Called ==="
    Rails.logger.info "Params: #{params.inspect}"

    rotation_match = @rotation.rotation_matches.find_by(match_index: @rotation.current_match_index)

    unless rotation_match
      Rails.logger.error "Rotation match not found for index: #{@rotation.current_match_index}"
      redirect_to @rotation, alert: '試合が見つかりません。' and return
    end

    # Create match record
    match = @rotation.event.matches.build(
      played_at: Time.current,
      winning_team: params[:winning_team].to_i
    )

    # Build match players before saving
    [
      { user: rotation_match.team1_player1, mobile_suit_id: params[:team1_player1_suit], team: 1, position: 1 },
      { user: rotation_match.team1_player2, mobile_suit_id: params[:team1_player2_suit], team: 1, position: 2 },
      { user: rotation_match.team2_player1, mobile_suit_id: params[:team2_player1_suit], team: 2, position: 3 },
      { user: rotation_match.team2_player2, mobile_suit_id: params[:team2_player2_suit], team: 2, position: 4 }
    ].each do |mp|
      match.match_players.build(
        user: mp[:user],
        mobile_suit_id: mp[:mobile_suit_id],
        team_number: mp[:team],
        position: mp[:position]
      )
    end

    begin
      if match.save
        # Link rotation match to match
        rotation_match.update(match: match)

        # Move to next match
        if @rotation.current_match_index < @rotation.rotation_matches.count - 1
          @rotation.increment!(:current_match_index)
        end

        Rails.logger.info "Match recorded successfully: #{match.id}"
        redirect_to @rotation, notice: '試合を記録しました。'
      else
        Rails.logger.error "Match save failed: #{match.errors.full_messages}"
        redirect_to @rotation, alert: "試合の記録に失敗しました: #{match.errors.full_messages.join(', ')}"
      end
    rescue => e
      Rails.logger.error "Exception in record_match: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to @rotation, alert: "試合の記録中にエラーが発生しました: #{e.message}"
    end
  end

  # Player view for real-time status
  def player_view
    @current_user_id = viewing_as_user.id
    @next_match = @rotation.next_match_for_player(@current_user_id)
    @player_statistics = @rotation.player_statistics

    if @next_match
      @match_info = @rotation.match_info_for_player(@next_match, @current_user_id)
      @matches_until_next = @next_match.match_index - @rotation.current_match_index
    end

    # Auto-refresh every 30 seconds
    response.headers['Refresh'] = '30'
  end

  # Copy rotation for next round
  def copy_for_next_round
    @rotation = Rotation.find(params[:id])

    new_rotation = @rotation.event.rotations.create!(
      name: "#{@rotation.name} - #{@rotation.round_number + 1}周目",
      round_number: @rotation.round_number + 1,
      base_rotation_id: @rotation.id
    )

    # Copy rotation matches
    @rotation.rotation_matches.order(:match_index).each do |rm|
      new_rotation.rotation_matches.create!(
        match_index: rm.match_index,
        team1_player1: rm.team1_player1,
        team1_player2: rm.team1_player2,
        team2_player1: rm.team2_player1,
        team2_player2: rm.team2_player2
      )
    end

    redirect_to new_rotation, notice: "#{new_rotation.round_number}周目のローテーションを作成しました。"
  end

  private

  def set_rotation
    @rotation = Rotation.find(params[:id])
  end

  def set_event
    @event = Event.find(params[:event_id])
  end

  def rotation_params
    params.require(:rotation).permit(:name, :round_number)
  end

  def generate_rotation_matches(rotation, player_ids)
    return unless player_ids.present?

    players = User.where(id: player_ids).to_a
    return if players.size < 4

    # Use RotationGenerator service to create balanced matches
    generator = RotationGenerator.new(players)
    matches = generator.generate

    # Create rotation matches from generated data
    matches.each do |match_data|
      rotation.rotation_matches.create!(
        match_index: match_data[:match_index],
        team1_player1: match_data[:team1_player1],
        team1_player2: match_data[:team1_player2],
        team2_player1: match_data[:team2_player1],
        team2_player2: match_data[:team2_player2]
      )
    end
  end
end
