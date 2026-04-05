class RotationShowSnapshot
  def initialize(rotation:, show_completion_modal:)
    @rotation = rotation
    @show_completion_modal = show_completion_modal
  end

  def to_h
    preload_current_match_favorites

    {
      rotation_matches: rotation_matches,
      current_match: current_match,
      player_statistics: rotation.player_statistics(rotation_matches),
      all_mobile_suits: MobileSuit.order(:name).to_a,
      show_completion_modal: show_completion_modal
    }
  end

  private

  attr_reader :rotation, :show_completion_modal

  def rotation_matches
    @rotation_matches ||= rotation.rotation_matches
                                 .includes(
                                   :team1_player1,
                                   :team1_player2,
                                   :team2_player1,
                                   :team2_player2,
                                   match: { match_players: :mobile_suit }
                                 )
                                 .order(:match_index)
                                 .to_a
  end

  def current_match
    @current_match ||= rotation_matches[rotation.current_match_index]
  end

  def preload_current_match_favorites
    return unless current_match

    ActiveRecord::Associations::Preloader.new(
      records: current_match.players,
      associations: :user_favorite_suits
    ).call
  end
end
