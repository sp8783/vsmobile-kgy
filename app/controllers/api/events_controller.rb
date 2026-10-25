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
      EventDataAnnouncer.announce_later(event)
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
    # 一括取得（exvs2ib-vsmobile-scraper）から届いた全試合分の統計。1 試合ずつ Vsmobile::MatchImporter で取り込む
    # （VS.モバイル連携で先に届いている試合は触らない。試合数がそろっていなくても、届いた分だけ取り込む）
    def stats
      event = Event.find_by(id: params[:id])
      return render json: { error: "Event not found" }, status: :not_found unless event

      payload = JSON.parse(request.body.read)
      unless payload.is_a?(Hash) && payload["matches"].is_a?(Array)
        return render json: { error: "リクエストボディは matches キーを持つ JSON オブジェクトである必要があります" }, status: :unprocessable_entity
      end

      matches_data  = payload["matches"]
      expired_users = Array(payload["expired_users"])

      imported = 0
      already = 0
      failed = []
      matches_data.each do |match_data|
        result = ::Vsmobile::MatchImporter.new(event: event, parsed: match_data).import!
        result.status == :imported ? imported += 1 : already += 1
      rescue ::Vsmobile::MatchImporter::NoMatchError, ActiveRecord::RecordInvalid => e
        failed << { match_ts: match_data["match_ts"], error: e.message }
      end

      PushNotificationService.notify_expired_cookies(event: event, users: expired_users) if expired_users.any?
      if failed.any?
        PushNotificationService.notify_stats_failed(event: event, error: "#{failed.size} 試合を取り込めませんでした: #{failed.first[:error]}")
      end
      EventStatsFollowUp.call(event) if imported.positive?

      status = imported.zero? && already.zero? && failed.any? ? :unprocessable_entity : :ok
      render json: { message: status == :ok ? "OK" : "NG", updated: imported, already: already, failed: failed, expired_users: expired_users }, status: status
    rescue JSON::ParserError
      render json: { error: "リクエストボディが不正な JSON 形式です" }, status: :unprocessable_entity
    end
  end
end
