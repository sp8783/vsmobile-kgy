class StatisticsPersonalTabSnapshot
  TAB_SNAPSHOT_CLASSES = {
    "overview" => StatisticsPersonalOverviewSnapshot,
    "partners" => StatisticsPersonalPartnersSnapshot,
    "mobile_suits" => StatisticsPersonalSuitsSnapshot,
    "opponent_suits" => StatisticsPersonalSuitsSnapshot,
    "events" => StatisticsPersonalEventsSnapshot,
    "opponents" => StatisticsPersonalOpponentsSnapshot,
    "event_progression" => StatisticsPersonalEventProgressionSnapshot
  }.freeze

  def initialize(tab:, filtered_matches:)
    @tab = tab
    @filtered_matches_relation = filtered_matches
    @filtered_matches = filtered_matches.to_a
  end

  def to_h
    return {} unless snapshot_class

    snapshot_class.new(
      filtered_matches: filtered_matches,
      filtered_matches_relation: filtered_matches_relation
    ).to_h
  end

  private

  attr_reader :tab, :filtered_matches, :filtered_matches_relation

  def snapshot_class
    TAB_SNAPSHOT_CLASSES[tab]
  end
end
