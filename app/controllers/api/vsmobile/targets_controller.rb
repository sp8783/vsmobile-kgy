module Api
  module Vsmobile
    # GET /api/vsmobile/targets
    # ブックマークレットに「どの日の試合を送ってほしいか」を教える: 直近 30 日（VS.モバイルに対戦履歴が残る期間）に
    # 自分が出たイベントと、既に届いている試合の開始時刻（送らなくてよい試合）
    class TargetsController < BaseController
      RETENTION_DAYS = 30

      def show
        events = Event.where(held_on: RETENTION_DAYS.days.ago.to_date..Date.current)
                      .joins(matches: :match_players).where(match_players: { user_id: current_user.id })
                      .distinct.order(held_on: :desc)

        render json: {
          user: { nickname: current_user.nickname },
          events: events.map { |event| event_json(event) }
        }
      end

      private

      def event_json(event)
        coverage = ::Vsmobile::Coverage.new(event: event)
        {
          id: event.id,
          name: event.name,
          held_on: event.held_on.iso8601,
          total: coverage.total,
          covered: coverage.covered_count,
          complete: coverage.complete?,
          covered_match_ts: coverage.matches.filter_map { |match| match.game_started_at&.to_i },
          url: event_url(event)
        }
      end

      def event_url(event)
        Rails.application.routes.url_helpers.event_url(event, **Rails.application.config.action_mailer.default_url_options)
      end
    end
  end
end
