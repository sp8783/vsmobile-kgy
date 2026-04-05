class StatisticsFilterOptions
  def initialize(user:, filter_events:)
    @user = user
    @filter_events = filter_events
  end

  def to_h
    {
      all_events: Event.order(held_on: :desc),
      all_mobile_suits: MobileSuit.order(:name),
      all_partners: all_partners
    }
  end

  private

  attr_reader :user, :filter_events

  def all_partners
    partners = User.regular_users.where.not(id: user.id).order(:nickname)
    return partners unless filter_events.any?

    partner_ids_in_events = MatchPlayer.joins(:match)
                                       .where(matches: { event_id: filter_events })
                                       .where.not(user_id: user.id)
                                       .distinct
                                       .pluck(:user_id)
    partners.where(id: partner_ids_in_events)
  end
end
