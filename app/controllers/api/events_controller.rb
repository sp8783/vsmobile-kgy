module Api
  class EventsController < BaseController
    def timestamps
      event = Event.find_by(id: params[:id])
      return render json: { error: "Event not found" }, status: :not_found unless event

      result = EventAnalysisTimestamps.new(event: event).apply(params[:timestamps].to_s)
      unless result.success?
        error_msg = result.error_message
        PushNotificationService.notify_timestamps_failed(event: event, error: error_msg)
        return render json: { error: error_msg }, status: :unprocessable_entity
      end

      # 試合の開始時刻から計算したタイムスタンプがあれば比べた結果を、なければ登録したことを知らせる
      if result.comparison
        PushNotificationService.notify_timestamps_compared(event: event, summary: result.comparison.summary)
      else
        PushNotificationService.notify_timestamps_registered(event: event, count: result.updated_count)
      end
      render json: { message: "OK", updated: result.updated_count, comparison: result.comparison&.summary }
    end

    def notify_failure
      event = Event.find_by(id: params[:id])
      return render json: { error: "Event not found" }, status: :not_found unless event

      # source: 失敗したツール（stats = 統計のスクレイピング、それ以外 = タイムスタンプ解析）
      error_msg = params[:error].presence || "不明なエラー"
      if params[:source] == "stats"
        PushNotificationService.notify_stats_failed(event: event, error: error_msg)
      else
        PushNotificationService.notify_timestamps_failed(event: event, error: error_msg)
      end
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

      db_matches = event.matches.includes(:match_timeline, :stats_payload, match_players: [ :user ]).order(:played_at, :id)

      if matches_data.size != db_matches.size
        return render json: {
          error: "データ件数（#{matches_data.size}）とイベント内試合数（#{db_matches.size}）が一致しません"
        }, status: :unprocessable_entity
      end

      ActiveRecord::Base.transaction do
        db_matches.each_with_index do |match, index|
          MatchTimelineImporter.new(match: match, parsed: matches_data[index]).apply!
        end
      end

      PushNotificationService.notify_expired_cookies(event: event, users: expired_users) if expired_users.any?

      # 1試合目の配信上の時刻が入っていれば、取り込んだ試合の開始時刻から全試合のタイムスタンプを計算する。
      # 動画解析のタイムスタンプが先に届いていれば、あわせて比べる
      timestamp_count = EventTimestampCalculator.new(event: event).apply!
      if timestamp_count
        PushNotificationService.notify_timestamps_registered(event: event, count: timestamp_count)
        comparison = EventTimestampComparison.new(event: event)
        PushNotificationService.notify_timestamps_compared(event: event, summary: comparison.summary) if comparison.comparable?
      end

      render json: { message: "OK", updated: db_matches.size, expired_users: expired_users }
    rescue JSON::ParserError
      render json: { error: "リクエストボディが不正な JSON 形式です" }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
