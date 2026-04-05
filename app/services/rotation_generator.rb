class RotationGenerator
  MATCH_PLAYER_KEYS = %i[
    team1_player1
    team1_player2
    team2_player1
    team2_player2
  ].freeze

  def initialize(players)
    @players = players
  end

  def generate
    template.each_with_index.map do |player_indexes, match_index|
      build_match(match_index, player_indexes.flatten)
    end
  end

  private

  attr_reader :players

  def template
    @template ||= RotationTemplateCatalog.fetch(players.size)
  end

  def build_match(match_index, player_indexes)
    { match_index: match_index }.merge(
      MATCH_PLAYER_KEYS.zip(player_indexes).to_h do |key, player_index|
        [ key, players[player_index] ]
      end
    )
  end
end
