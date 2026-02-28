class MatchStatsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_match

  def edit
    @players = @match.match_players.includes(:user, :mobile_suit).order(:position)
    @match_timeline = @match.match_timeline || @match.build_match_timeline
  end

  def update
    ActiveRecord::Base.transaction do
      # タイムラインを更新（フルJSON の場合は統計・チームフラグも自動投入）
      handle_timeline_update

      # スコアの降順で順位を自動計算して保存（統計投入後に実行）
      recalculate_match_ranks
    end

    redirect_to @match, notice: "統計データを保存しました。"
  rescue ActiveRecord::RecordInvalid => e
    @players = @match.match_players.includes(:user, :mobile_suit).order(:position)
    @match_timeline = @match.match_timeline || @match.build_match_timeline
    flash.now[:alert] = "保存に失敗しました: #{e.message}"
    render :edit, status: :unprocessable_entity
  end

  def destroy
    ActiveRecord::Base.transaction do
      # プレイヤー統計をリセット
      stat_columns = %i[match_rank score kills deaths damage_dealt damage_received
                        exburst_damage exburst_count exburst_deaths
                        last_death_ex_available survive_loss_ex_available ex_overlimit_activated]
      @match.match_players.update_all(stat_columns.index_with(nil))

      # チームフラグをリセット
      @match.update!(
        team1_ex_overlimit_before_end: nil,
        team2_ex_overlimit_before_end: nil
      )

      # タイムラインを削除
      @match.match_timeline&.destroy!
    end

    redirect_to @match, notice: "統計データを削除しました。"
  rescue => e
    redirect_to edit_match_stats_path(@match), alert: "削除に失敗しました: #{e.message}"
  end

  private

  def set_match
    @match = Match.includes(:event, :match_timeline, match_players: [ :user, :mobile_suit ]).find(params[:match_id])
  end

  # スコア降順で1〜4位を自動計算して match_rank に保存
  def recalculate_match_ranks
    players = @match.match_players.reload
    with_score    = players.select { |mp| mp.score.present? }.sort_by { |mp| -mp.score }
    without_score = players.reject { |mp| mp.score.present? }

    MatchPlayer.where(id: without_score.map(&:id)).update_all(match_rank: nil) if without_score.any?
    with_score.each_with_index do |mp, i|
      MatchPlayer.where(id: mp.id).update_all(match_rank: i + 1)
    end
  end

  def handle_timeline_update
    raw_json = params.dig(:match_timeline, :timeline_raw_text).presence

    if raw_json.nil?
      @match.match_timeline&.destroy!
      return
    end

    parsed = JSON.parse(raw_json)

    # フルワークフロー JSON（team_a / team_b を含む）とベア timeline_raw 形式の両方をサポート
    if parsed["timeline_raw"]
      # スコア等ワークフローJSONにしか存在しない統計・チームフラグを投入
      import_from_workflow_json(parsed)

      tl = parsed["timeline_raw"].merge(
        "_player_order" => {
          "team1" => parsed.dig("team_a", "players")&.map { |p| p["name"] }&.compact,
          "team2" => parsed.dig("team_b", "players")&.map { |p| p["name"] }&.compact
        }.compact
      )
    else
      tl = parsed
    end

    game_end_cs  = tl["game_end_cs"]
    game_end_str = tl["game_end_str"]

    if @match.match_timeline
      @match.match_timeline.update!(
        timeline_raw: tl,
        game_end_cs: game_end_cs,
        game_end_str: game_end_str
      )
    else
      @match.create_match_timeline!(
        timeline_raw: tl,
        game_end_cs: game_end_cs,
        game_end_str: game_end_str
      )
    end

    # タイムライン保存後に常にタイムライン由来の統計を再計算
    # ベアJSONの再保存でも exburst_count/deaths・EXバースト残し系フラグが更新される
    recalculate_timeline_derived_stats
  rescue JSON::ParserError
    raise ActiveRecord::RecordInvalid.new(MatchTimeline.new.tap { |t| t.errors.add(:timeline_raw, "が不正な JSON 形式です") })
  end

  # フルワークフロー JSON からスコア等（タイムラインに存在しない値）とチームフラグを投入する
  def import_from_workflow_json(data)
    name_to_mp = @match.match_players.each_with_object({}) { |mp, h| h[mp.user.nickname] = mp }
    tl_events  = data.dig("timeline_raw", "events") || []

    # 名前 → グループキーのマッピング（team_a.players[i] → "team1-{i+1}"）
    name_to_group = {}
    (data.dig("team_a", "players") || []).each_with_index { |p, i| name_to_group[p["name"]] = "team1-#{i + 1}" }
    (data.dig("team_b", "players") || []).each_with_index { |p, i| name_to_group[p["name"]] = "team2-#{i + 1}" }

    team_flag_updates = {}

    [ data["team_a"], data["team_b"] ].each do |team_data|
      next unless team_data

      players = team_data["players"] || []

      # DB team_number を1人目のプレイヤーの名前突合で特定
      db_team_num = name_to_mp[players.first&.dig("name")]&.team_number

      if db_team_num
        # チームフラグ: 全員に exbst-ov イベントがない → OL未発動 → true
        group_keys  = players.map { |p| name_to_group[p["name"]] }.compact
        team_has_ol = group_keys.any? { |gk| tl_events.any? { |e| e["group"] == gk && e["class_name"] == "exbst-ov" } }
        team_flag_updates[:"team#{db_team_num}_ex_overlimit_before_end"] = !team_has_ol
      end

      # スコア・ダメージ等（タイムラインに存在しない値のみ）
      players.each do |pj|
        mp = name_to_mp[pj["name"]]
        next unless mp

        mp.update!(
          score:           pj["score"],
          kills:           pj["kills"],
          deaths:          pj["deaths"],
          damage_dealt:    pj["damage_dealt"],
          damage_received: pj["damage_received"],
          exburst_damage:  pj["exburst_damage"]
        )
      end
    end

    @match.update!(team_flag_updates) if team_flag_updates.any?
  end

  # 保存済みタイムラインから導出可能な統計を再計算する
  # ベアJSONの再保存でも正しく動作するよう handle_timeline_update から常に呼ばれる
  def recalculate_timeline_derived_stats
    tl = @match.match_timeline
    return unless tl

    tl_data      = tl.timeline_raw || {}
    tl_events    = tl_data["events"] || []
    game_end_cs  = tl_data["game_end_cs"] || Float::INFINITY
    player_order = tl_data["_player_order"] || {}

    # _player_order から name → group key マッピングを構築
    name_to_group = {}
    (player_order["team1"] || []).each_with_index { |name, i| name_to_group[name] = "team1-#{i + 1}" }
    (player_order["team2"] || []).each_with_index { |name, i| name_to_group[name] = "team2-#{i + 1}" }
    return if name_to_group.empty?

    name_to_mp       = @match.match_players.each_with_object({}) { |mp, h| h[mp.user.nickname] = mp }
    last_death_group = tl_events.select { |e| e["is_point"] }.max_by { |e| e["start_cs"] || 0 }&.dig("group")

    name_to_mp.each do |name, mp|
      group_key = name_to_group[name]
      next unless group_key

      player_events = tl_events.select { |e| e["group"] == group_key }
      burst_events  = player_events.select { |e| %w[exbst-f exbst-s exbst-e].include?(e["class_name"]) }
      ex_zones      = player_events.select { |e| e["class_name"] == "ex" }

      # exburst_count: バースト発動イベントの数
      exburst_count = burst_events.size

      # exburst_deaths: 被撃墜時刻がバースト区間内に含まれる数
      exburst_deaths = player_events.select { |e| e["is_point"] }.count do |death|
        cs = death["start_cs"]
        burst_events.any? { |b| b["start_cs"] && b["end_cs"] && b["start_cs"] <= cs && cs < b["end_cs"] }
      end

      # EXゾーン判定ヘルパー
      ex_available_at = lambda do |cs|
        in_ex    = ex_zones.any?     { |e| e["start_cs"] && e["end_cs"] && e["start_cs"] <= cs && cs <= e["end_cs"] }
        in_burst = burst_events.any? { |b| b["start_cs"] && b["end_cs"] && b["start_cs"] <= cs && cs <= b["end_cs"] }
        in_ex && !in_burst
      end

      # 属性1: 試合を決めた被撃墜時にEX可能域かつ未発動
      last_death_ex_available = if group_key == last_death_group
        last_death = player_events.select { |e| e["is_point"] }.max_by { |e| e["start_cs"] || 0 }
        ex_available_at.call([ last_death["start_cs"], game_end_cs ].min) if last_death
      end

      # 属性2: 試合終了時に被撃墜されていないプレイヤー — 試合終了時点でEX可能域かつ未発動
      survive_loss_ex_available = if group_key != last_death_group && game_end_cs != Float::INFINITY
        ex_available_at.call(game_end_cs)
      end

      mp.update!(
        exburst_count:             exburst_count,
        exburst_deaths:            exburst_deaths,
        last_death_ex_available:   last_death_ex_available,
        survive_loss_ex_available: survive_loss_ex_available
      )
    end
  end
end
