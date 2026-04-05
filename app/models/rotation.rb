class Rotation < ApplicationRecord
  # Associations
  belongs_to :event
  belongs_to :base_rotation, class_name: "Rotation", optional: true
  has_many :derived_rotations, class_name: "Rotation", foreign_key: "base_rotation_id", dependent: :nullify
  has_many :rotation_matches, dependent: :destroy

  # Validations
  validates :round_number, presence: true, numericality: { greater_than: 0 }
  validates :current_match_index, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def display_name
    "#{round_number}周目"
  end

  def players
    User.where(id: rotation_matches.flat_map(&:player_ids).uniq)
  end

  def player_count
    players.count
  end

  # 8人の場合のみ1セット6試合、それ以外は1セット3試合
  def matches_per_set
    player_count == 8 ? 6 : 3
  end

  # Calculate statistics for each player
  # rotation_matches_scope: preloaded scope (includes :match) to avoid N+1
  def player_statistics(rotation_matches_scope = nil)
    scope = rotation_matches_scope || rotation_matches.includes(:match)

    stats = Hash.new do |h, k|
      h[k] = {
        user: nil,
        match_count: 0,
        registered_match_count: 0,
        streaming_count: 0,
        registered_streaming_count: 0,
        pair_counts: Hash.new(0),
        opponent_counts: Hash.new(0)
      }
    end

    scope.each do |rm|
      all_players = rm.players
      registered = rm.match.present?

      # Update match counts
      all_players.each do |player|
        stats[player.id][:user] = player
        stats[player.id][:match_count] += 1
        stats[player.id][:registered_match_count] += 1 if registered
      end

      # Update streaming seat (team1_player1) counts
      streamer = rm.team1_players.first
      stats[streamer.id][:streaming_count] += 1
      stats[streamer.id][:registered_streaming_count] += 1 if registered

      # Update pair counts
      [ rm.team1_players, rm.team2_players ].each do |pair|
        stats[pair[0].id][:pair_counts][pair[1].id] += 1
        stats[pair[1].id][:pair_counts][pair[0].id] += 1
      end

      # Update opponent counts
      rm.team1_players.each do |team1_player|
        rm.team2_players.each do |team2_player|
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
      .where("match_index >= ?", current_match_index)
      .where(
        "team1_player1_id = ? OR team1_player2_id = ? OR team2_player1_id = ? OR team2_player2_id = ?",
        player_id, player_id, player_id, player_id
      )
      .order(:match_index)
      .first
  end

  # Get player's partner and opponents for a specific match
  def match_info_for_player(rotation_match, player_id)
    seat_info = rotation_match.seat_info_for(player_id)
    return nil unless seat_info[:seat]

    seat_info.slice(:partner, :opponents)
  end
end
