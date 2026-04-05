module Api
  class EventsController < BaseController
    include MatchStatsImportable

    def timestamps
      event = Event.find_by(id: params[:id])
      return render json: { error: "Event not found" }, status: :not_found unless event

      result = EventTimestampBatch.new(event: event).update(params[:timestamps].to_s)
      unless result.success?
        error_msg = result.error_message
        PushNotificationService.notify_timestamps_failed(event: event, error: error_msg)
        return render json: { error: error_msg }, status: :unprocessable_entity
      end

      PushNotificationService.notify_timestamps_registered(event: event, count: result.updated_count)
      render json: { message: "OK", updated: result.updated_count }
    end

    def notify_failure
      event = Event.find_by(id: params[:id])
      return render json: { error: "Event not found" }, status: :not_found unless event

      error_msg = params[:error].presence || "不明なエラー"
      PushNotificationService.notify_timestamps_failed(event: event, error: error_msg)
      render json: { message: "OK" }
    end

    # POST /api/events/:id/stats
    def stats
      event = Event.find_by(id: params[:id])
      return render json: { error: "Event not found" }, status: :not_found unless event

      payload = JSON.parse(request.body.read)
      unless payload.is_a?(Hash) && payload["matches"].is_a?(Array)
        return render json: { error: "リクエストボディは matches キーを持つ JSON オブジェクトである必要があります" }, status: :unprocessable_entity
      end

      matches_data  = payload["matches"]
      expired_users = Array(payload["expired_users"])

      db_matches = event.matches.includes(:match_timeline, match_players: [ :user ]).order(:played_at, :id)

      if matches_data.size != db_matches.size
        return render json: {
          error: "データ件数（#{matches_data.size}）とイベント内試合数（#{db_matches.size}）が一致しません"
        }, status: :unprocessable_entity
      end

      ActiveRecord::Base.transaction do
        db_matches.each_with_index do |match, i|
          @match = match
          apply_timeline_data(matches_data[i])
          recalculate_match_ranks
        end
      end

      PushNotificationService.notify_expired_cookies(event: event, users: expired_users) if expired_users.any?

      render json: { message: "OK", updated: db_matches.size, expired_users: expired_users }
    rescue JSON::ParserError
      render json: { error: "リクエストボディが不正な JSON 形式です" }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
