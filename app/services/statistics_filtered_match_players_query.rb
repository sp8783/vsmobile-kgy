class StatisticsFilteredMatchPlayersQuery
  def initialize(user:, filter_events:, filter_mobile_suits:, filter_partners:, filter_costs:)
    @user = user
    @filter_events = filter_events
    @filter_mobile_suits = filter_mobile_suits
    @filter_partners = filter_partners
    @filter_costs = filter_costs
  end

  def call
    scope = MatchPlayer.where(user_id: user.id)
                       .joins(:match)
                       .includes(
                         :mobile_suit,
                         :user,
                         match: [
                           :event,
                           { rotation_match: :rotation },
                           { match_players: [ :user, :mobile_suit ] }
                         ]
                       )

    scope = scope.where(matches: { event_id: filter_events }) if filter_events.any?
    scope = scope.where(mobile_suit_id: filter_mobile_suits) if filter_mobile_suits.any?
    scope = scope.where(mobile_suit_id: MobileSuit.where(cost: filter_costs)) if filter_costs.any?
    return scope unless filter_partners.any?

    filtered_match_ids = scope.select do |match_player|
      partner = match_player.partner
      partner && filter_partners.include?(partner.user_id)
    end.map(&:match_id).uniq

    scope.where(matches: { id: filtered_match_ids })
  end

  private

  attr_reader :user, :filter_events, :filter_mobile_suits, :filter_partners, :filter_costs
end
