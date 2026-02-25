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
      # チームフラグを更新
      @match.assign_attributes(match_team_flags_params)
      @match.save!

      # プレイヤー統計を更新
      player_stats_params.each do |id, attrs|
        mp = @match.match_players.find(id)
        mp.update!(attrs)
      end

      # タイムラインを更新
      handle_timeline_update
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
                        exburst_damage exburst_count exburst_deaths ex_overlimit_activated]
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

  def match_team_flags_params
    params.require(:match).permit(:team1_ex_overlimit_before_end, :team2_ex_overlimit_before_end)
  end

  def player_stats_params
    return {} unless params[:match_players].present?

    stat_fields = %i[match_rank score kills deaths damage_dealt damage_received
                     exburst_damage exburst_count exburst_deaths ex_overlimit_activated]
    @match.match_players.each_with_object({}) do |mp, result|
      next unless params[:match_players][mp.id.to_s]
      result[mp.id] = params[:match_players][mp.id.to_s].permit(*stat_fields).to_h
    end
  end

  def handle_timeline_update
    raw_json = params.dig(:match_timeline, :timeline_raw_text).presence

    if raw_json.nil?
      @match.match_timeline&.destroy!
      return
    end

    parsed = JSON.parse(raw_json)
    game_end_cs = parsed["game_end_cs"]
    game_end_str = parsed["game_end_str"]

    if @match.match_timeline
      @match.match_timeline.update!(
        timeline_raw: parsed,
        game_end_cs: game_end_cs,
        game_end_str: game_end_str
      )
    else
      @match.create_match_timeline!(
        timeline_raw: parsed,
        game_end_cs: game_end_cs,
        game_end_str: game_end_str
      )
    end
  rescue JSON::ParserError
    raise ActiveRecord::RecordInvalid.new(MatchTimeline.new.tap { |t| t.errors.add(:timeline_raw, "が不正な JSON 形式です") })
  end
end
