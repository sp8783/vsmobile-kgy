class MatchTimelineImporter
  def initialize(match:, parsed:)
    @match = match
    @parsed = parsed
  end

  def apply!
    timeline_data = normalized_timeline_data

    upsert_match_timeline!(timeline_data)
    recalculate_timeline_derived_stats!
    recalculate_match_ranks!
  end

  private

  attr_reader :match, :parsed

  def normalized_timeline_data
    return parsed unless workflow_payload?

    import_from_workflow_json!

    parsed["timeline_raw"].merge(
      "_player_order" => {
        "team1" => parsed.dig("team_a", "players")&.map { |player| player["name"] }&.compact,
        "team2" => parsed.dig("team_b", "players")&.map { |player| player["name"] }&.compact
      }.compact
    )
  end

  def workflow_payload?
    !parsed["timeline_raw"].nil?
  end

  def upsert_match_timeline!(timeline_data)
    attributes = {
      timeline_raw: timeline_data,
      game_end_cs: timeline_data["game_end_cs"],
      game_end_str: timeline_data["game_end_str"]
    }

    if match.match_timeline
      match.match_timeline.update!(attributes)
    else
      match.create_match_timeline!(attributes)
    end
  end

  def recalculate_match_ranks!
    players = match.match_players.reload
    with_score = players.select { |match_player| match_player.score.present? }.sort_by { |match_player| -match_player.score }
    without_score = players.reject { |match_player| match_player.score.present? }

    MatchPlayer.where(id: without_score.map(&:id)).update_all(match_rank: nil) if without_score.any?
    with_score.each_with_index do |match_player, index|
      MatchPlayer.where(id: match_player.id).update_all(match_rank: index + 1)
    end
  end

  def import_from_workflow_json!
    timeline_events = parsed.dig("timeline_raw", "events") || []
    team_flag_updates = {}

    [ parsed["team_a"], parsed["team_b"] ].each do |team_data|
      next unless team_data

      players = team_data["players"] || []
      db_team_num = match_player_by_name(players.first&.dig("name"))&.team_number

      if db_team_num
        group_keys = players.map { |player| group_key_for(player["name"]) }.compact
        team_has_ol = group_keys.any? do |group_key|
          timeline_events.any? { |event| event["group"] == group_key && event["class_name"] == "exbst-ov" }
        end
        team_flag_updates[:"team#{db_team_num}_ex_overlimit_before_end"] = !team_has_ol
      end

      players.each do |player_json|
        match_player = match_player_by_name(player_json["name"])
        next unless match_player

        match_player.update!(
          score: player_json["score"],
          kills: player_json["kills"],
          deaths: player_json["deaths"],
          damage_dealt: player_json["damage_dealt"],
          damage_received: player_json["damage_received"],
          exburst_damage: player_json["exburst_damage"]
        )
      end
    end

    match.update!(team_flag_updates) if team_flag_updates.any?
  end

  def recalculate_timeline_derived_stats!
    timeline = match.match_timeline
    return unless timeline

    timeline_data = timeline.timeline_raw || {}
    timeline_events = timeline_data["events"] || []
    game_end_cs = timeline_data["game_end_cs"] || Float::INFINITY
    player_order = timeline_data["_player_order"] || {}
    name_to_group = build_name_to_group(player_order)
    return if name_to_group.empty?

    last_death_group = timeline_events.select { |event| event["is_point"] }
                                      .max_by { |event| event["start_cs"] || 0 }
                                      &.dig("group")

    match_players_by_name.each do |name, match_player|
      group_key = name_to_group[name]
      next unless group_key

      player_events = timeline_events.select { |event| event["group"] == group_key }
      burst_events = player_events.select { |event| %w[exbst-f exbst-s exbst-e].include?(event["class_name"]) }
      ex_zones = player_events.select { |event| event["class_name"] == "ex" }
      death_times = player_events.select { |event| event["is_point"] }
                                 .sort_by { |event| event["start_cs"] || 0 }
                                 .map { |event| event["start_cs"] }
                                 .compact

      match_player.update!(
        exburst_count: burst_events.size,
        first_unit_exburst_count: first_unit_exburst_count(burst_events, player_events),
        exburst_deaths: exburst_deaths_count(burst_events, player_events),
        last_death_ex_available: last_death_ex_available?(group_key, last_death_group, player_events, ex_zones, burst_events, game_end_cs),
        survive_loss_ex_available: survive_loss_ex_available?(group_key, last_death_group, ex_zones, burst_events, game_end_cs),
        survival_times: survival_times_for(death_times, group_key, last_death_group, game_end_cs)
      )
    end
  end

  def build_name_to_group(player_order)
    {}.tap do |mapping|
      (player_order["team1"] || []).each_with_index { |name, index| mapping[name] = "team1-#{index + 1}" }
      (player_order["team2"] || []).each_with_index { |name, index| mapping[name] = "team2-#{index + 1}" }
    end
  end

  def first_unit_exburst_count(burst_events, player_events)
    first_death_cs = player_events.select { |event| event["is_point"] }
                                  .map { |event| event["start_cs"] }
                                  .compact
                                  .min

    return burst_events.size unless first_death_cs

    burst_events.count { |burst_event| (burst_event["start_cs"] || 0) < first_death_cs }
  end

  def exburst_deaths_count(burst_events, player_events)
    player_events.select { |event| event["is_point"] }.count do |death_event|
      timestamp = death_event["start_cs"]
      burst_events.any? do |burst_event|
        burst_event["start_cs"] && burst_event["end_cs"] &&
          burst_event["start_cs"] <= timestamp && timestamp <= burst_event["end_cs"]
      end
    end
  end

  def last_death_ex_available?(group_key, last_death_group, player_events, ex_zones, burst_events, game_end_cs)
    return unless group_key == last_death_group

    last_death = player_events.select { |event| event["is_point"] }
                              .max_by { |event| event["start_cs"] || 0 }
    return unless last_death

    ex_available_at?([ last_death["start_cs"], game_end_cs ].min, ex_zones, burst_events)
  end

  def survive_loss_ex_available?(group_key, last_death_group, ex_zones, burst_events, game_end_cs)
    return if group_key == last_death_group || game_end_cs == Float::INFINITY

    ex_available_at?(game_end_cs, ex_zones, burst_events)
  end

  def survival_times_for(death_times, group_key, last_death_group, game_end_cs)
    return game_end_cs != Float::INFINITY ? [ game_end_cs.to_i ] : [] if death_times.empty?

    survival_times = []
    previous_timestamp = 0

    death_times.each do |timestamp|
      survival_times << (timestamp - previous_timestamp)
      previous_timestamp = timestamp
    end

    alive_at_end = group_key != last_death_group && game_end_cs != Float::INFINITY
    survival_times << (game_end_cs.to_i - previous_timestamp) if alive_at_end
    survival_times
  end

  def ex_available_at?(timestamp, ex_zones, burst_events)
    in_ex_zone = ex_zones.any? do |event|
      event["start_cs"] && event["end_cs"] &&
        event["start_cs"] <= timestamp && timestamp <= event["end_cs"]
    end
    in_burst = burst_events.any? do |event|
      event["start_cs"] && event["end_cs"] &&
        event["start_cs"] <= timestamp && timestamp <= event["end_cs"]
    end

    in_ex_zone && !in_burst
  end

  def match_players_by_name
    @match_players_by_name ||= match.match_players.each_with_object({}) do |match_player, mapping|
      mapping[match_player.user.nickname] = match_player
    end
  end

  def match_player_by_name(name)
    match_players_by_name[name]
  end

  def group_key_for(player_name)
    @group_keys_by_name ||= begin
      {}.tap do |mapping|
        (parsed.dig("team_a", "players") || []).each_with_index do |player, index|
          mapping[player["name"]] = "team1-#{index + 1}"
        end
        (parsed.dig("team_b", "players") || []).each_with_index do |player, index|
          mapping[player["name"]] = "team2-#{index + 1}"
        end
      end
    end

    @group_keys_by_name[player_name]
  end
end
