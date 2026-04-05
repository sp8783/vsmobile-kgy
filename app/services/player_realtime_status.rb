class PlayerRealtimeStatus
  def initialize(user:)
    @user = user
  end

  def to_h
    {
      today_event: today_event,
      active_rotation: active_rotation,
      rotation_matches: rotation_matches,
      rotation_total_matches: rotation_matches.size,
      rotation_current_match_index: active_rotation&.current_match_index,
      current_rotation_match: current_rotation_match,
      user_next_rotation_match: user_next_rotation_match,
      matches_until_user_turn: matches_until_user_turn,
      match_info: match_info,
      user_partner: match_info&.dig(:partner),
      opponent_players: match_info&.dig(:opponents) || [],
      is_streaming: user_next_rotation_match&.streaming_for?(user.id) || false
    }
  end

  private

  attr_reader :user

  def today_event
    @today_event ||= Event.find_by(held_on: Time.zone.today)
  end

  def active_rotation
    @active_rotation ||= today_event&.rotations&.includes(
      rotation_matches: [ :team1_player1, :team1_player2, :team2_player1, :team2_player2 ]
    )&.find_by(is_active: true)
  end

  def rotation_matches
    @rotation_matches ||= active_rotation ? active_rotation.rotation_matches.sort_by(&:match_index) : []
  end

  def current_rotation_match
    @current_rotation_match ||= rotation_matches[active_rotation.current_match_index] if active_rotation
  end

  def user_next_rotation_match
    @user_next_rotation_match ||= if active_rotation
      rotation_matches.find do |rotation_match|
        rotation_match.match_index >= active_rotation.current_match_index &&
          rotation_match.includes_player?(user.id)
      end
    end
  end

  def matches_until_user_turn
    return unless user_next_rotation_match && active_rotation

    user_next_rotation_match.match_index - active_rotation.current_match_index
  end

  def match_info
    @match_info ||= active_rotation&.match_info_for_player(user_next_rotation_match, user.id) if user_next_rotation_match
  end
end
