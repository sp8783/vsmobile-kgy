module Events
  # イベントの試合の統計（各試合のスコア・撃墜・タイムラインなど）の登録。
  # 登録のしかたは 2 つ: VS.モバイルから一括取得する・試合ごとに入力する
  class StatsController < ApplicationController
    TABS = %w[bulk per_match].freeze

    before_action :authenticate_user!
    before_action :require_admin
    before_action :set_event

    def show
      @tab = TABS.include?(params[:tab]) ? params[:tab] : TABS.first
      @matches = @event.matches.includes(:match_timeline, match_players: :user).order(:played_at, :id)
    end

    # VS.モバイルの戦績のスクレイピング（exvs2ib-vsmobile-scraper）を GitHub Actions で始める
    def scraping
      dispatch_result = GithubActionsWorkflowDispatcher.new(
        repo: ENV["SCRAPER_GITHUB_REPO"].presence,
        workflow_id: ENV["SCRAPER_GITHUB_WORKFLOW_ID"].presence,
        token: ENV["GITHUB_TOKEN"].presence,
        inputs: {
          event_id: @event.id.to_s
        },
        missing_config_message: "スクレイパーの設定が不完全です（SCRAPER_GITHUB_REPO / SCRAPER_GITHUB_WORKFLOW_ID / GITHUB_TOKEN を確認してください）。",
        exception_message_prefix: "スクレイピング開始でエラーが発生しました"
      ).call

      if dispatch_result.success?
        redirect_to event_stats_path(@event, tab: "bulk"), notice: "統計スクレイピングを開始しました。完了後に統計データが自動登録されます。"
      else
        redirect_to event_stats_path(@event, tab: "bulk"), alert: dispatch_result.error_message
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end
  end
end
