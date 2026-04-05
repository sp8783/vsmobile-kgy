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
      update_timeline_data!
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
      MatchStatisticsResetter.new(match: @match).reset!
    end

    redirect_to @match, notice: "統計データを削除しました。"
  rescue => e
    redirect_to edit_match_stats_path(@match), alert: "削除に失敗しました: #{e.message}"
  end

  private

  def set_match
    @match = Match.includes(:event, :match_timeline, match_players: [ :user, :mobile_suit ]).find(params[:match_id])
  end

  def update_timeline_data!
    raw_json = params.dig(:match_timeline, :timeline_raw_text).presence
    return @match.match_timeline&.destroy! if raw_json.nil?

    MatchTimelineImporter.new(match: @match, parsed: parse_timeline_json(raw_json)).apply!
  end

  def parse_timeline_json(raw_json)
    JSON.parse(raw_json)
  rescue JSON::ParserError
    raise ActiveRecord::RecordInvalid.new(
      MatchTimeline.new.tap { |t| t.errors.add(:timeline_raw, "が不正な JSON 形式です") }
    )
  end
end
