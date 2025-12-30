class Rotation < ApplicationRecord
  # Associations
  belongs_to :event
  belongs_to :base_rotation, class_name: 'Rotation', optional: true
  has_many :derived_rotations, class_name: 'Rotation', foreign_key: 'base_rotation_id', dependent: :nullify
  has_many :rotation_matches, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :round_number, presence: true, numericality: { greater_than: 0 }
  validates :current_match_index, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Get all unique players in this rotation
  def players
    player_ids = rotation_matches.flat_map do |rm|
      [rm.team1_player1_id, rm.team1_player2_id, rm.team2_player1_id, rm.team2_player2_id]
    end.uniq

    User.where(id: player_ids)
  end

  # Calculate statistics for each player
  def player_statistics
    stats = Hash.new do |h, k|
      h[k] = {
        user: nil,
        match_count: 0,
        pair_counts: Hash.new(0),
        opponent_counts: Hash.new(0)
      }
    end

    rotation_matches.each do |rm|
      all_players = [rm.team1_player1, rm.team1_player2, rm.team2_player1, rm.team2_player2]

      # Update match counts
      all_players.each do |player|
        stats[player.id][:user] = player
        stats[player.id][:match_count] += 1
      end

      # Update pair counts
      [[rm.team1_player1, rm.team1_player2], [rm.team2_player1, rm.team2_player2]].each do |pair|
        stats[pair[0].id][:pair_counts][pair[1].id] += 1
        stats[pair[1].id][:pair_counts][pair[0].id] += 1
      end

      # Update opponent counts
      [rm.team1_player1, rm.team1_player2].each do |team1_player|
        [rm.team2_player1, rm.team2_player2].each do |team2_player|
          stats[team1_player.id][:opponent_counts][team2_player.id] += 1
          stats[team2_player.id][:opponent_counts][team1_player.id] += 1
        end
      end
    end

    stats
  end

  # Find next match for a specific player
  def next_match_for_player(player_id)
    rotation_matches
      .where('match_index >= ?', current_match_index)
      .where(
        'team1_player1_id = ? OR team1_player2_id = ? OR team2_player1_id = ? OR team2_player2_id = ?',
        player_id, player_id, player_id, player_id
      )
      .order(:match_index)
      .first
  end

  # Get player's partner and opponents for a specific match
  def match_info_for_player(rotation_match, player_id)
    if rotation_match.team1_player1_id == player_id
      { partner: rotation_match.team1_player2, opponents: [rotation_match.team2_player1, rotation_match.team2_player2] }
    elsif rotation_match.team1_player2_id == player_id
      { partner: rotation_match.team1_player1, opponents: [rotation_match.team2_player1, rotation_match.team2_player2] }
    elsif rotation_match.team2_player1_id == player_id
      { partner: rotation_match.team2_player2, opponents: [rotation_match.team1_player1, rotation_match.team1_player2] }
    elsif rotation_match.team2_player2_id == player_id
      { partner: rotation_match.team2_player1, opponents: [rotation_match.team1_player1, rotation_match.team1_player2] }
    else
      nil
    end
  end
end
