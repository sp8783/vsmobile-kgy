class EventMatchListing
  SORT_OPTIONS = %w[oldest reactions].freeze
  PER_PAGE_OPTIONS = [ 10, 20, 50 ].freeze

  def initialize(event:, params:, viewing_as_user:)
    @event = event
    @params = params
    @viewing_as_user = viewing_as_user
  end

  def to_h
    {
      sort: sort,
      per_page: per_page,
      matches: matches,
      rotations: event.rotations.order(created_at: :asc),
      emojis: MasterEmoji.active.ordered,
      match_numbers: match_numbers,
      my_favorite_match_ids: favorite_match_ids
    }
  end

  private

  attr_reader :event, :params, :viewing_as_user

  def sort
    @sort ||= params[:sort].presence_in(SORT_OPTIONS) || "oldest"
  end

  def per_page
    @per_page ||= PER_PAGE_OPTIONS.include?(params[:per].to_i) ? params[:per].to_i : 20
  end

  def matches
    @matches ||= match_scope.page(params[:page]).per(per_page)
  end

  def match_numbers
    ordered_ids = event.matches.order(:played_at, :id).pluck(:id)
    ordered_ids.each_with_index.to_h { |id, index| [ id, index + 1 ] }
  end

  def favorite_match_ids
    return Set.new unless viewing_as_user

    FavoriteMatch.where(user_id: viewing_as_user.id, match_id: matches.map(&:id)).pluck(:match_id).to_set
  end

  def match_scope
    base_scope = sort == "reactions" ? event.matches.by_reactions_oldest : event.matches.by_oldest
    base_scope.includes(:event, :rotation_match, match_players: [ :user, :mobile_suit ], reactions: :user)
  end
end
