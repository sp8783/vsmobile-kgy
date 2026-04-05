class MatchesFilterOptions
  def initialize(filter_events:)
    @filter_events = filter_events
  end

  def to_h
    {
      all_events: Event.order(held_on: :desc),
      all_mobile_suits: MobileSuit.order(Arel.sql("position IS NULL, position ASC, cost DESC, name ASC")),
      all_users: all_users
    }
  end

  private

  attr_reader :filter_events

  def all_users
    users = User.regular_users.order(:nickname)
    return users unless filter_events.any?

    user_ids_in_events = MatchPlayer.joins(:match)
                                    .where(matches: { event_id: filter_events })
                                    .distinct
                                    .pluck(:user_id)
    users.where(id: user_ids_in_events)
  end
end
