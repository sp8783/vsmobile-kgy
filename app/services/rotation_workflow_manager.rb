class RotationWorkflowManager
  Result = Struct.new(:success?, :rotation, :new_rotation, :completed, :error_message, keyword_init: true)

  def initialize(rotation:)
    @rotation = rotation
  end

  def generate_matches!(player_ids:)
    return success_result(rotation: rotation) unless player_ids.present?

    players = User.where(id: player_ids).to_a
    return success_result(rotation: rotation) if players.size < 4

    ActiveRecord::Base.transaction do
      generate_matches_for_rotation!(rotation, players)
    end

    success_result(rotation: rotation)
  rescue StandardError => error
    failure_result(error.message)
  end

  def activate!
    ActiveRecord::Base.transaction do
      rotation.event.rotations.update_all(is_active: false)
      rotation.update!(is_active: true)
      mark_current_match_started(rotation)
    end

    PushNotificationService.notify_rotation_activated(rotation: rotation)
    notify_upcoming_players(rotation)
    success_result(rotation: rotation)
  rescue StandardError => error
    failure_result(error.message)
  end

  def deactivate!
    rotation.update!(is_active: false)
    success_result(rotation: rotation)
  rescue StandardError => error
    failure_result(error.message)
  end

  def next_match!
    return failure_result("これが最後の試合です。") unless next_match_available?

    rotation.increment!(:current_match_index)
    mark_current_match_started(rotation)
    broadcast_rotation_update(rotation)
    notify_upcoming_players(rotation)
    success_result(rotation: rotation)
  rescue StandardError => error
    failure_result(error.message)
  end

  def go_to_match!(match_index:)
    return failure_result("無効な試合番号です。") unless valid_match_index?(match_index)

    rotation.update!(current_match_index: match_index)
    mark_current_match_started(rotation)
    broadcast_rotation_update(rotation)
    success_result(rotation: rotation)
  rescue StandardError => error
    failure_result(error.message)
  end

  def record_current_match!(winning_team:, suit_ids:)
    rotation_match = rotation.rotation_matches.find_by(match_index: rotation.current_match_index)
    return failure_result("試合が見つかりません。") unless rotation_match

    match = rotation.event.matches.build(
      played_at: Time.current,
      winning_team: winning_team,
      rotation_match: rotation_match
    )
    build_match_players(match, rotation_match, suit_ids)

    completed = false

    ActiveRecord::Base.transaction do
      unless match.save
        raise ActiveRecord::Rollback
      end

      rotation_match.update!(match: match)
      rotation.sync_current_match_index!
      mark_current_match_started(rotation)

      completed = rotation.rotation_matches.where(match_id: nil).none?
      rotation.update!(is_active: false) if completed
    end

    return failure_result("試合の記録に失敗しました: #{match.errors.full_messages.join(', ')}") if match.errors.any?

    broadcast_rotation_update(rotation)
    notify_upcoming_players(rotation) unless completed
    success_result(rotation: rotation, completed: completed)
  rescue StandardError => error
    failure_result("試合の記録中にエラーが発生しました: #{error.message}")
  end

  def update_match_record!(match_index:, winning_team:, suit_ids:)
    rotation_match = rotation.rotation_matches.find_by(match_index: match_index)
    return failure_result("試合が見つかりません。") unless rotation_match&.match

    match = rotation_match.match

    ActiveRecord::Base.transaction do
      match.winning_team = winning_team
      match.match_players.destroy_all
      build_match_players(match, rotation_match, suit_ids)

      unless match.save
        raise ActiveRecord::Rollback
      end
    end

    if match.errors.any?
      failure_result("試合記録の更新に失敗しました: #{match.errors.full_messages.join(', ')}")
    else
      success_result(rotation: rotation)
    end
  rescue StandardError => error
    failure_result("試合記録の更新中にエラーが発生しました: #{error.message}")
  end

  def copy_for_next_round!
    new_rotation = nil

    ActiveRecord::Base.transaction do
      new_rotation = rotation.event.rotations.create!(
        round_number: rotation.round_number + 1,
        base_rotation_id: rotation.id
      )

      generate_matches_for_rotation!(new_rotation, player_ids_for_next_round)
      rotation.event.rotations.update_all(is_active: false)
      new_rotation.update!(is_active: true)
      mark_current_match_started(new_rotation)
    end

    PushNotificationService.notify_rotation_activated(rotation: new_rotation)
    notify_upcoming_players(new_rotation)
    success_result(rotation: rotation, new_rotation: new_rotation)
  rescue StandardError => error
    failure_result(error.message)
  end

  private

  attr_reader :rotation

  def next_match_available?
    rotation.current_match_index < rotation.rotation_matches.count - 1
  end

  def valid_match_index?(match_index)
    match_index >= 0 && match_index < rotation.rotation_matches.count
  end

  def build_match_players(match, rotation_match, suit_ids)
    rotation_match.match_player_attributes(suit_ids).each do |attributes|
      match.match_players.build(
        user: attributes[:user],
        mobile_suit_id: attributes[:mobile_suit_id],
        team_number: attributes[:team_number],
        position: attributes[:position]
      )
    end
  end

  def notify_upcoming_players(target_rotation)
    current_index = target_rotation.current_match_index
    ordered_matches = target_rotation.rotation_matches
                                   .includes(:team1_player1, :team1_player2, :team2_player1, :team2_player2)
                                   .order(:match_index)
                                   .to_a

    ordered_matches.flat_map(&:player_ids).uniq.each do |player_id|
      next_match = ordered_matches.find do |rotation_match|
        rotation_match.match_index >= current_index &&
          rotation_match.match_id.nil? &&
          rotation_match.includes_player?(player_id)
      end
      next unless next_match

      matches_until_turn = next_match.match_index - current_index
      next if matches_until_turn > 2

      user = User.find_by(id: player_id)
      next unless user

      seat_info = next_match.seat_info_for(player_id)
      if matches_until_turn.zero?
        PushNotificationService.notify_match_now(
          user: user,
          rotation: target_rotation,
          match_number: next_match.match_index + 1,
          seat_position: seat_info[:seat],
          partner_name: seat_info[:partner]&.nickname
        )
      else
        PushNotificationService.notify_match_upcoming(
          user: user,
          matches_until_turn: matches_until_turn,
          rotation: target_rotation,
          current_match_number: current_index + 1,
          seat_position: seat_info[:seat],
          partner_name: seat_info[:partner]&.nickname
        )
      end
    end
  end

  def mark_current_match_started(target_rotation)
    rotation_match = target_rotation.rotation_matches.find_by(match_index: target_rotation.current_match_index)
    rotation_match&.update!(started_at: Time.current) if rotation_match&.started_at.nil?
  end

  def broadcast_rotation_update(target_rotation)
    RotationChannel.broadcast_to(
      target_rotation,
      {
        type: "rotation_updated",
        current_match_index: target_rotation.current_match_index
      }
    )
  end

  def player_ids_for_next_round
    rotation.rotation_matches.flat_map(&:player_ids).uniq
  end

  def generate_matches_for_rotation!(target_rotation, player_ids)
    players = player_ids.all? { |player| player.is_a?(User) } ? player_ids : User.where(id: player_ids).to_a
    return if players.size < 4

    RotationGenerator.new(players.shuffle).generate.each do |match_data|
      target_rotation.rotation_matches.create!(
        match_index: match_data[:match_index],
        team1_player1: match_data[:team1_player1],
        team1_player2: match_data[:team1_player2],
        team2_player1: match_data[:team2_player1],
        team2_player2: match_data[:team2_player2]
      )
    end
  end

  def success_result(rotation:, new_rotation: nil, completed: false)
    Result.new(success?: true, rotation: rotation, new_rotation: new_rotation, completed: completed)
  end

  def failure_result(error_message)
    Result.new(success?: false, rotation: rotation, error_message: error_message)
  end
end
