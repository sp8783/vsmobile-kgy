class RotationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin, except: [:index, :show]
  before_action :set_rotation, only: [:show, :edit, :update, :destroy, :activate, :deactivate, :next_match, :record_match, :go_to_match, :update_match_record]
  before_action :set_event, only: [:new, :create]

  def index
    @rotations = Rotation.includes(:event, :rotation_matches).order(created_at: :desc)
  end

  def show
    @rotation_matches = @rotation.rotation_matches
                                  .includes(:team1_player1, :team1_player2, :team2_player1, :team2_player2, :match)
                                  .order(:match_index)
    @current_match = @rotation_matches[@rotation.current_match_index]
    @player_statistics = @rotation.player_statistics

    # Check if we should show completion modal
    if session[:show_completion_modal] == @rotation.id
      @show_completion_modal = true
      session.delete(:show_completion_modal)
    end
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
      # Generate rotation matches
      generate_rotation_matches(@rotation, player_ids)
      redirect_to @rotation, notice: 'ローテーションを作成しました。'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @players = User.regular_users.order(:nickname)
  end

  def update
    if @rotation.update(rotation_params)
      redirect_to @rotation, notice: 'ローテーションを更新しました。'
    else
      @players = User.regular_users.order(:nickname)
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

    # Record started_at for the current match
    mark_current_match_started(@rotation)

    # Send push notifications to all players
    PushNotificationService.notify_rotation_activated(rotation: @rotation)

    # Send upcoming match notifications (1試合目の出番通知含む)
    notify_upcoming_players(@rotation)

    redirect_to @rotation, notice: 'ローテーションをアクティブにしました。'
  end

  # Deactivate this rotation
  def deactivate
    @rotation.update(is_active: false)
    redirect_to @rotation, notice: 'ローテーションを非アクティブにしました。'
  end

  # Move to next match
  def next_match
    if @rotation.current_match_index < @rotation.rotation_matches.count - 1
      @rotation.increment!(:current_match_index)

      # Record started_at for the current match
      mark_current_match_started(@rotation)

      # Broadcast update via Action Cable
      RotationChannel.broadcast_to(@rotation, {
        type: 'rotation_updated',
        current_match_index: @rotation.current_match_index
      })

      # Send push notifications to upcoming players
      notify_upcoming_players(@rotation)

      redirect_to @rotation, notice: '次の試合に進みました。'
    else
      redirect_to @rotation, alert: 'これが最後の試合です。'
    end
  end

  # Go to specific match (for skipped matches)
  def go_to_match
    match_index = params[:match_index].to_i

    if match_index >= 0 && match_index < @rotation.rotation_matches.count
      @rotation.update!(current_match_index: match_index)

      # Record started_at for the current match
      mark_current_match_started(@rotation)

      # Broadcast update via Action Cable
      RotationChannel.broadcast_to(@rotation, {
        type: 'rotation_updated',
        current_match_index: @rotation.current_match_index
      })

      redirect_to @rotation, notice: "第#{match_index + 1}試合に戻りました。"
    else
      redirect_to @rotation, alert: '無効な試合番号です。'
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
      winning_team: params[:winning_team].to_i,
      rotation_match: rotation_match
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

        # Move to next unrecorded match
        next_unrecorded_index = find_next_unrecorded_match_index(@rotation)
        if next_unrecorded_index
          @rotation.update!(current_match_index: next_unrecorded_index)
          mark_current_match_started(@rotation)
        end

        # Broadcast update via Action Cable
        RotationChannel.broadcast_to(@rotation, {
          type: 'rotation_updated',
          current_match_index: @rotation.current_match_index
        })

        # Check if all matches are completed
        all_completed = @rotation.rotation_matches.all? { |rm| rm.match.present? }

        # Send push notifications to upcoming players
        notify_upcoming_players(@rotation) unless all_completed

        Rails.logger.info "Match recorded successfully: #{match.id}"

        if all_completed
          # All matches completed - deactivate this rotation and show modal to create next round
          @rotation.update!(is_active: false)
          session[:show_completion_modal] = @rotation.id
          redirect_to @rotation, notice: '試合を記録しました。'
        else
          redirect_to @rotation, notice: '試合を記録しました。'
        end
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
  # DEPRECATED: Player view is now integrated into the dashboard
  # def player_view
  #   @current_user_id = viewing_as_user.id
  #   @next_match = @rotation.next_match_for_player(@current_user_id)
  #   @player_statistics = @rotation.player_statistics
  #
  #   if @next_match
  #     @match_info = @rotation.match_info_for_player(@next_match, @current_user_id)
  #     @matches_until_next = @next_match.match_index - @rotation.current_match_index
  #   end
  #
  #   # Real-time updates via Action Cable (no HTTP refresh needed)
  # end

  # Update existing match record without moving rotation
  def update_match_record
    rotation_match = @rotation.rotation_matches.find_by(match_index: params[:match_index].to_i)

    unless rotation_match && rotation_match.match
      redirect_to @rotation, alert: '試合が見つかりません。' and return
    end

    match = rotation_match.match

    # Update match record
    match.winning_team = params[:winning_team].to_i

    # Update match players
    match.match_players.destroy_all
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

    if match.save
      redirect_to @rotation, notice: '試合記録を更新しました。'
    else
      redirect_to @rotation, alert: "試合記録の更新に失敗しました: #{match.errors.full_messages.join(', ')}"
    end
  rescue => e
    redirect_to @rotation, alert: "試合記録の更新中にエラーが発生しました: #{e.message}"
  end

  # Copy rotation for next round
  def copy_for_next_round
    @rotation = Rotation.find(params[:id])

    new_rotation = @rotation.event.rotations.create!(
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

    # Deactivate all rotations for this event
    @rotation.event.rotations.update_all(is_active: false)

    # Activate the new rotation
    new_rotation.update!(is_active: true)

    # Record started_at for the first match
    mark_current_match_started(new_rotation)

    # Send push notifications for new round
    PushNotificationService.notify_rotation_activated(rotation: new_rotation)
    notify_upcoming_players(new_rotation)

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
    params.require(:rotation).permit(:round_number)
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

  def notify_upcoming_players(rotation)
    current_index = rotation.current_match_index
    rotation_matches = rotation.rotation_matches
                               .includes(:team1_player1, :team1_player2, :team2_player1, :team2_player2)
                               .order(:match_index)

    # 全プレイヤーのIDを収集
    all_player_ids = rotation_matches.flat_map do |rm|
      [ rm.team1_player1_id, rm.team1_player2_id, rm.team2_player1_id, rm.team2_player2_id ]
    end.compact.uniq

    # 各プレイヤーの「次の試合」を特定して通知
    all_player_ids.each do |player_id|
      # このプレイヤーの次の試合を探す（current_index以降でまだ記録されていない試合）
      next_match = rotation_matches.find do |rm|
        rm.match_index >= current_index &&
        rm.match_id.nil? &&
        (rm.team1_player1_id == player_id ||
         rm.team1_player2_id == player_id ||
         rm.team2_player1_id == player_id ||
         rm.team2_player2_id == player_id)
      end

      next unless next_match

      matches_until = next_match.match_index - current_index

      # 3試合以上先は通知しない
      next if matches_until > 2

      # 座席情報とパートナーを特定
      seat_info = determine_seat_info(next_match, player_id)
      user = User.find_by(id: player_id)
      next unless user

      if matches_until == 0
        PushNotificationService.notify_match_now(
          user: user,
          rotation: rotation,
          match_number: next_match.match_index + 1,
          seat_position: seat_info[:seat],
          partner_name: seat_info[:partner]&.nickname
        )
      else
        PushNotificationService.notify_match_upcoming(
          user: user,
          matches_until_turn: matches_until,
          rotation: rotation,
          current_match_number: current_index + 1,
          seat_position: seat_info[:seat],
          partner_name: seat_info[:partner]&.nickname
        )
      end
    end
  end

  def determine_seat_info(rotation_match, player_id)
    case player_id
    when rotation_match.team1_player1_id
      { seat: :seat_1, partner: rotation_match.team1_player2 }  # 1番席（配信台）
    when rotation_match.team1_player2_id
      { seat: :seat_2, partner: rotation_match.team1_player1 }  # 2番席（配信台の隣）
    when rotation_match.team2_player1_id
      { seat: :seat_3, partner: rotation_match.team2_player2 }  # 3番席
    when rotation_match.team2_player2_id
      { seat: :seat_4, partner: rotation_match.team2_player1 }  # 4番席
    else
      { seat: nil, partner: nil }
    end
  end

  def mark_current_match_started(rotation)
    rm = rotation.rotation_matches.find_by(match_index: rotation.current_match_index)
    rm&.update!(started_at: Time.current) if rm && rm.started_at.nil?
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
