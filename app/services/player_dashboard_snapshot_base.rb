class PlayerDashboardSnapshotBase
  def initialize(user:, match_players:)
    @user = user
    @match_players = match_players.to_a
  end

  private

  attr_reader :user, :match_players

  def stats_match_players
    @stats_match_players ||= match_players.select(&:has_stats?)
  end

  def positive_damage_match_players
    @positive_damage_match_players ||= stats_match_players.select do |match_player|
      match_player.damage_dealt.to_i > 0
    end
  end

  def recent_10_results
    @recent_10_results ||= unique_recent_match_players(limit: 10).map(&:won?)
  end

  def unique_recent_match_players(limit: nil)
    seen_match_ids = {}
    unique_match_players = []

    match_players.each do |match_player|
      next if seen_match_ids[match_player.match_id]

      seen_match_ids[match_player.match_id] = true
      unique_match_players << match_player
      break if limit && unique_match_players.size >= limit
    end

    unique_match_players
  end

  def event_match_players(event_id)
    match_players.select { |match_player| match_player.match.event_id == event_id }
  end

  def win_count(target_match_players)
    target_match_players.count(&:won?)
  end

  def decorate_mobile_suit(mobile_suit, stats)
    win_rate = percentage(stats[:wins], stats[:count])

    mobile_suit.tap do |suit|
      suit.define_singleton_method(:usage_count) { stats[:count] }
      suit.define_singleton_method(:win_rate) { win_rate }
    end
  end

  def average(target_match_players, &block)
    target_match_players.sum(&block).to_f / target_match_players.size
  end

  def percentage(numerator, denominator)
    denominator.positive? ? (numerator.to_f / denominator * 100).round(1) : 0
  end
end
