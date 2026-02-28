class MatchStatsController < ApplicationController
  include MatchStatsImportable

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

  def handle_timeline_update
    raw_json = params.dig(:match_timeline, :timeline_raw_text).presence
    return @match.match_timeline&.destroy! if raw_json.nil?

    apply_timeline_data(JSON.parse(raw_json))
  rescue JSON::ParserError
    raise ActiveRecord::RecordInvalid.new(
      MatchTimeline.new.tap { |t| t.errors.add(:timeline_raw, "が不正な JSON 形式です") }
    )
  end
end
