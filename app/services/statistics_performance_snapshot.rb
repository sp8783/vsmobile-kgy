class StatisticsPerformanceSnapshot
  SECTION_CLASSES = [
    StatisticsPerformanceSummarySnapshot,
    StatisticsPerformanceSelfComparisonSnapshot,
    StatisticsPerformanceCommunityExburstSnapshot,
    StatisticsPerformanceCommunityOverlimitSnapshot,
    StatisticsPerformanceCommunityDistributionSnapshot,
    StatisticsPerformanceSurvivalTimeSnapshot
  ].freeze

  def initialize(user:, filtered_matches:, filter_events:, filter_mobile_suits:, filter_costs:)
    @context = StatisticsPerformanceSnapshotContext.new(
      user: user,
      filtered_matches: filtered_matches,
      filter_events: filter_events,
      filter_mobile_suits: filter_mobile_suits,
      filter_costs: filter_costs
    )
  end

  def to_h
    SECTION_CLASSES.each_with_object({}) do |section_class, attributes|
      attributes.merge!(section_class.new(context: context).to_h)
    end
  end

  private

  attr_reader :context
end
