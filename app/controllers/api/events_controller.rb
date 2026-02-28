module Api
  class EventsController < BaseController
    include TimestampParseable
    include MatchStatsImportable

    def timestamps
      event = Event.find_by(id: params[:id])
      return render json: { error: "Event not found" }, status: :not_found unless event

      raw_text = params[:timestamps].to_s
      lines = raw_text.split("\n").map(&:strip)
      lines.pop while lines.last&.empty?

      matches = event.matches.order(:played_at, :id)

      if lines.size != matches.size
        error_msg = "行数（#{lines.size}）と試合数（#{matches.size}）が一致しません。"
        PushNotificationService.notify_timestamps_failed(event: event, error: error_msg)
        return render json: { error: error_msg }, status: :unprocessable_entity
      end

      parsed = lines.map.with_index do |line, i|
        seconds = parse_timestamp(line)
        unless seconds
          error_msg = "#{i + 1}行目「#{line}」の形式が不正です。H:MM:SS または MM:SS の形式で入力してください。"
          PushNotificationService.notify_timestamps_failed(event: event, error: error_msg)
          return render json: { error: error_msg }, status: :unprocessable_entity
        end
        seconds
      end

      ActiveRecord::Base.transaction do
        matches.each_with_index do |match, i|
          match.update!(video_timestamp: parsed[i])
        end
      end

      PushNotificationService.notify_timestamps_registered(event: event, count: matches.size)
      render json: { message: "OK", updated: matches.size }
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

      matches_data = request.request_parameters
      unless matches_data.is_a?(Array)
        return render json: { error: "リクエストボディは JSON 配列である必要があります" }, status: :unprocessable_entity
      end

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

      render json: { message: "OK", updated: db_matches.size }
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
