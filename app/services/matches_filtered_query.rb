class MatchesFilteredQuery
  def initialize(filter_state:, viewing_as_user:)
    @filter_state = filter_state
    @viewing_as_user = viewing_as_user
  end

  def call
    scope = base_scope
    scope = apply_event_filter(scope)
    scope = apply_user_filter(scope)
    scope = apply_streaming_user_filter(scope)
    scope = apply_mobile_suit_filter(scope)
    scope = apply_cost_filter(scope)
    scope = apply_ol_filter(scope)
    scope = apply_stat_filters(scope)
    scope = apply_damage_filter(scope, :damage_dealt, filter_state.filter_damage_dealt_val, filter_state.filter_damage_dealt_dir)
    scope = apply_damage_filter(scope, :damage_received, filter_state.filter_damage_received_val, filter_state.filter_damage_received_dir)
    scope = apply_team_filter(scope)
    scope = apply_favorites_filter(scope)
    scope
  end

  private

  attr_reader :filter_state, :viewing_as_user

  def base_scope
    sorted_scope.includes(:event, { match_players: [ :user, :mobile_suit ] }, { reactions: :user })
  end

  def sorted_scope
    case filter_state.sort
    when "reactions" then Match.by_reactions
    when "oldest" then Match.by_oldest
    else Match.by_latest
    end
  end

  def suit_scope_mine?
    filter_state.filter_suit_scope == "mine" && viewing_as_user.present?
  end

  def apply_event_filter(scope)
    return scope unless filter_state.filter_events.any?

    scope.where(event_id: filter_state.filter_events)
  end

  def apply_user_filter(scope)
    return scope unless filter_state.filter_users.any?

    if filter_state.filter_users_mode == "and"
      filter_state.filter_users.reduce(scope) do |current_scope, user_id|
        current_scope.where(
          "EXISTS (SELECT 1 FROM match_players mp WHERE mp.match_id = matches.id AND mp.user_id = ?)",
          user_id
        )
      end
    else
      scope.joins(:match_players).where(match_players: { user_id: filter_state.filter_users }).distinct
    end
  end

  def apply_streaming_user_filter(scope)
    return scope unless filter_state.filter_streaming_users.any?

    if filter_state.filter_streaming_users_mode == "and"
      filter_state.filter_streaming_users.reduce(scope) do |current_scope, user_id|
        current_scope.where(
          "EXISTS (SELECT 1 FROM match_players mp WHERE mp.match_id = matches.id AND mp.user_id = ? AND mp.team_number = 1 AND mp.position = 1)",
          user_id
        )
      end
    else
      scope.joins(:match_players).where(
        match_players: { user_id: filter_state.filter_streaming_users, team_number: 1, position: 1 }
      ).distinct
    end
  end

  def apply_mobile_suit_filter(scope)
    return scope unless filter_state.filter_mobile_suits.any?

    match_player_filter = { mobile_suit_id: filter_state.filter_mobile_suits }
    match_player_filter[:user_id] = viewing_as_user.id if suit_scope_mine?
    scope.joins(:match_players).where(match_players: match_player_filter).distinct
  end

  def apply_cost_filter(scope)
    return scope unless filter_state.filter_costs.any?

    filtered_scope = scope.joins(match_players: :mobile_suit)
                          .where(mobile_suits: { cost: filter_state.filter_costs })
    filtered_scope = filtered_scope.where(match_players: { user_id: viewing_as_user.id }) if suit_scope_mine?
    filtered_scope.distinct
  end

  def apply_ol_filter(scope)
    case filter_state.filter_ol_filter
    when "ol_unused_win"
      ol_unused_win_scope(scope)
    when "ol_unused_loss"
      ol_unused_loss_scope(scope)
    else
      scope
    end
  end

  def ol_unused_win_scope(scope)
    filtered_scope = scope.where(
      "(winning_team = 1 AND team1_ex_overlimit_before_end = TRUE) OR " \
      "(winning_team = 2 AND team2_ex_overlimit_before_end = TRUE)"
    )
    return filtered_scope unless filter_state.filter_stat_player_id

    filtered_scope.joins(:match_players).where(
      "match_players.user_id = ? AND match_players.team_number = matches.winning_team",
      filter_state.filter_stat_player_id
    ).distinct
  end

  def ol_unused_loss_scope(scope)
    filtered_scope = scope.where(
      "(winning_team = 1 AND team2_ex_overlimit_before_end = TRUE) OR " \
      "(winning_team = 2 AND team1_ex_overlimit_before_end = TRUE)"
    )
    return filtered_scope unless filter_state.filter_stat_player_id

    filtered_scope.joins(:match_players).where(
      "match_players.user_id = ? AND match_players.team_number != matches.winning_team",
      filter_state.filter_stat_player_id
    ).distinct
  end

  def apply_stat_filters(scope)
    filter_state.filter_stat_filters.reduce(scope) do |current_scope, filter_name|
      case filter_name
      when "ex_leftover_loss"
        ex_leftover_loss_scope(current_scope)
      when "ex_leftover_win"
        ex_leftover_win_scope(current_scope)
      when "exburst_death"
        exburst_death_scope(current_scope)
      else
        current_scope
      end
    end
  end

  def ex_leftover_loss_scope(scope)
    filtered_scope = scope.joins(:match_players).where(
      "match_players.team_number != matches.winning_team AND " \
      "(match_players.last_death_ex_available = TRUE OR match_players.survive_loss_ex_available = TRUE)"
    )
    filtered_scope = filtered_scope.where(match_players: { user_id: filter_state.filter_stat_player_id }) if filter_state.filter_stat_player_id
    filtered_scope.distinct
  end

  def ex_leftover_win_scope(scope)
    filtered_scope = scope.where(
      "EXISTS (SELECT 1 FROM match_players mp WHERE mp.match_id = matches.id " \
      "AND mp.team_number != matches.winning_team " \
      "AND (mp.last_death_ex_available = TRUE OR mp.survive_loss_ex_available = TRUE))"
    )
    return filtered_scope unless filter_state.filter_stat_player_id

    filtered_scope.joins(:match_players).where(
      "match_players.user_id = ? AND match_players.team_number = matches.winning_team",
      filter_state.filter_stat_player_id
    ).distinct
  end

  def exburst_death_scope(scope)
    filtered_scope = scope.joins(:match_players).where("match_players.exburst_deaths > 0")
    filtered_scope = filtered_scope.where(match_players: { user_id: filter_state.filter_stat_player_id }) if filter_state.filter_stat_player_id
    filtered_scope.distinct
  end

  def apply_damage_filter(scope, column_name, raw_value, direction)
    return scope if raw_value.blank?

    operator = direction == "lte" ? "<=" : ">="
    filtered_scope = scope.joins(:match_players).where("match_players.#{column_name} #{operator} ?", raw_value.to_i)
    filtered_scope = filtered_scope.where(match_players: { user_id: filter_state.filter_stat_player_id }) if filter_state.filter_stat_player_id
    filtered_scope.distinct
  end

  def apply_team_filter(scope)
    return scope unless filter_state.filter_team_player_ids.any?

    if filter_state.filter_team_player_ids.length >= 2
      user_id_1, user_id_2 = filter_state.filter_team_player_ids.first(2)
      scope.where(
        "EXISTS (" \
        "SELECT 1 FROM match_players mp1 " \
        "JOIN match_players mp2 ON mp1.match_id = mp2.match_id AND mp1.team_number = mp2.team_number " \
        "WHERE mp1.match_id = matches.id AND mp1.user_id = ? AND mp2.user_id = ?" \
        ")",
        user_id_1, user_id_2
      )
    else
      scope.where(
        "EXISTS (SELECT 1 FROM match_players mp WHERE mp.match_id = matches.id AND mp.user_id = ?)",
        filter_state.filter_team_player_ids.first
      )
    end
  end

  def apply_favorites_filter(scope)
    return scope unless filter_state.filter_only_favorites && viewing_as_user

    scope.joins(:favorite_matches).where(favorite_matches: { user_id: viewing_as_user.id })
  end
end
