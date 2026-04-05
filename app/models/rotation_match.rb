class RotationMatch < ApplicationRecord
  PLAYER_SLOTS = [
    {
      player_key: :team1_player1,
      id_key: :team1_player1_id,
      team_number: 1,
      position: 1,
      seat: :seat_1,
      partner_key: :team1_player2,
      opponent_keys: %i[team2_player1 team2_player2]
    },
    {
      player_key: :team1_player2,
      id_key: :team1_player2_id,
      team_number: 1,
      position: 2,
      seat: :seat_2,
      partner_key: :team1_player1,
      opponent_keys: %i[team2_player1 team2_player2]
    },
    {
      player_key: :team2_player1,
      id_key: :team2_player1_id,
      team_number: 2,
      position: 3,
      seat: :seat_3,
      partner_key: :team2_player2,
      opponent_keys: %i[team1_player1 team1_player2]
    },
    {
      player_key: :team2_player2,
      id_key: :team2_player2_id,
      team_number: 2,
      position: 4,
      seat: :seat_4,
      partner_key: :team2_player1,
      opponent_keys: %i[team1_player1 team1_player2]
    }
  ].freeze

  # Associations
  belongs_to :rotation
  belongs_to :team1_player1, class_name: "User"
  belongs_to :team1_player2, class_name: "User"
  belongs_to :team2_player1, class_name: "User"
  belongs_to :team2_player2, class_name: "User"
  belongs_to :match, optional: true
  has_one :match_result, class_name: "Match", foreign_key: "rotation_match_id", dependent: :nullify

  # Validations
  validates :match_index, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :match_index, uniqueness: { scope: :rotation_id }

  def players
    PLAYER_SLOTS.filter_map { |slot| public_send(slot[:player_key]) }
  end

  def team1_players
    [ team1_player1, team1_player2 ].compact
  end

  def team2_players
    [ team2_player1, team2_player2 ].compact
  end

  def player_ids
    PLAYER_SLOTS.filter_map { |slot| public_send(slot[:id_key]) }
  end

  def includes_player?(player_or_id)
    player_ids.include?(extract_player_id(player_or_id))
  end

  def streaming_for?(player_or_id)
    extract_player_id(player_or_id) == team1_player1_id
  end

  def seat_info_for(player_or_id)
    slot = slot_for(player_or_id)
    return { seat: nil, partner: nil, opponents: [] } unless slot

    {
      seat: slot[:seat],
      partner: public_send(slot[:partner_key]),
      opponents: slot[:opponent_keys].filter_map { |key| public_send(key) }
    }
  end

  def match_player_attributes(mobile_suit_ids)
    PLAYER_SLOTS.map do |slot|
      {
        user: public_send(slot[:player_key]),
        mobile_suit_id: mobile_suit_ids[slot[:player_key]],
        team_number: slot[:team_number],
        position: slot[:position]
      }
    end
  end

  private

  def slot_for(player_or_id)
    player_id = extract_player_id(player_or_id)
    PLAYER_SLOTS.find { |slot| public_send(slot[:id_key]) == player_id }
  end

  def extract_player_id(player_or_id)
    player_or_id.respond_to?(:id) ? player_or_id.id : player_or_id
  end
end
