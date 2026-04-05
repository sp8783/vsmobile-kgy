class MatchesFilterState
  SORT_OPTIONS = %w[latest oldest reactions].freeze
  MODE_OPTIONS = %w[or and].freeze
  SUIT_SCOPE_OPTIONS = %w[mine all].freeze
  DIRECTION_OPTIONS = %w[gte lte].freeze
  OL_FILTER_OPTIONS = %w[ol_unused_win ol_unused_loss].freeze
  PER_PAGE_OPTIONS = [ 10, 20, 50 ].freeze

  def initialize(params:)
    @params = params
  end

  def to_h
    {
      sort: sort,
      per_page: per_page,
      filter_events: filter_events,
      filter_users: filter_users,
      filter_users_mode: filter_users_mode,
      filter_streaming_users: filter_streaming_users,
      filter_streaming_users_mode: filter_streaming_users_mode,
      filter_mobile_suits: filter_mobile_suits,
      filter_costs: filter_costs,
      filter_suit_scope: filter_suit_scope,
      flip_team: flip_team,
      filter_stat_player_id: filter_stat_player_id,
      filter_ol_filter: filter_ol_filter,
      filter_stat_filters: filter_stat_filters,
      filter_damage_dealt_val: filter_damage_dealt_val,
      filter_damage_dealt_dir: filter_damage_dealt_dir,
      filter_damage_received_val: filter_damage_received_val,
      filter_damage_received_dir: filter_damage_received_dir,
      filter_only_favorites: filter_only_favorites,
      filter_team_player_ids: filter_team_player_ids
    }
  end

  def sort
    @sort ||= params[:sort].presence_in(SORT_OPTIONS) || "latest"
  end

  def per_page
    @per_page ||= PER_PAGE_OPTIONS.include?(params[:per].to_i) ? params[:per].to_i : 20
  end

  def filter_events
    @filter_events ||= selected_ids(:events)
  end

  def filter_users
    @filter_users ||= selected_ids(:users)
  end

  def filter_users_mode
    @filter_users_mode ||= params[:users_mode].presence_in(MODE_OPTIONS) || "or"
  end

  def filter_streaming_users
    @filter_streaming_users ||= selected_ids(:streaming_users)
  end

  def filter_streaming_users_mode
    @filter_streaming_users_mode ||= params[:streaming_users_mode].presence_in(MODE_OPTIONS) || "or"
  end

  def filter_mobile_suits
    @filter_mobile_suits ||= selected_ids(:mobile_suits)
  end

  def filter_costs
    @filter_costs ||= selected_ids(:costs)
  end

  def filter_suit_scope
    @filter_suit_scope ||= params[:suit_scope].presence_in(SUIT_SCOPE_OPTIONS) || "all"
  end

  def flip_team
    @flip_team ||= params[:flip_team] == "1"
  end

  def filter_stat_player_id
    @filter_stat_player_id ||= params[:stat_player_id].presence&.to_i
  end

  def filter_ol_filter
    @filter_ol_filter ||= params[:ol_filter].presence_in(OL_FILTER_OPTIONS)
  end

  def filter_stat_filters
    @filter_stat_filters ||= Array(params[:stat_filters]).reject(&:blank?)
  end

  def filter_damage_dealt_val
    @filter_damage_dealt_val ||= params[:damage_dealt_val].presence
  end

  def filter_damage_dealt_dir
    @filter_damage_dealt_dir ||= params[:damage_dealt_dir].presence_in(DIRECTION_OPTIONS) || "gte"
  end

  def filter_damage_received_val
    @filter_damage_received_val ||= params[:damage_received_val].presence
  end

  def filter_damage_received_dir
    @filter_damage_received_dir ||= params[:damage_received_dir].presence_in(DIRECTION_OPTIONS) || "gte"
  end

  def filter_only_favorites
    @filter_only_favorites ||= params[:only_favorites] == "1"
  end

  def filter_team_player_ids
    @filter_team_player_ids ||= selected_ids(:team_player_ids)
  end

  private

  attr_reader :params

  def selected_ids(key)
    Array(params[key]).reject(&:blank?).map(&:to_i)
  end
end
