class PlayerDashboardSnapshot
  SNAPSHOT_CLASSES = [
    PlayerDashboardSummarySnapshot,
    PlayerDashboardTrendSnapshot,
    PlayerDashboardPerformanceSnapshot
  ].freeze

  def initialize(user:, match_players:)
    @user = user
    @match_players = match_players.to_a
  end

  def to_h
    SNAPSHOT_CLASSES.each_with_object({}) do |snapshot_class, attributes|
      attributes.merge!(snapshot_class.new(user: user, match_players: match_players).to_h)
    end
  end

  private

  attr_reader :user, :match_players
end
