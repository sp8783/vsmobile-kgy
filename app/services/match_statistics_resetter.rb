class MatchStatisticsResetter
  STAT_COLUMNS = %i[
    match_rank
    score
    kills
    deaths
    damage_dealt
    damage_received
    exburst_damage
    exburst_count
    first_unit_exburst_count
    exburst_deaths
    last_death_ex_available
    survive_loss_ex_available
    ex_overlimit_activated
  ].freeze

  def initialize(match:)
    @match = match
  end

  def reset!
    match.match_players.update_all(STAT_COLUMNS.index_with(nil))
    match.update!(
      team1_ex_overlimit_before_end: nil,
      team2_ex_overlimit_before_end: nil
    )
    match.match_timeline&.destroy!
  end

  private

  attr_reader :match
end
