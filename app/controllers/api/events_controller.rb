module Api
  class EventsController < BaseController
    include TimestampParseable

    def timestamps
      event = Event.find_by(id: params[:id])
      return render json: { error: "Event not found" }, status: :not_found unless event

      raw_text = params[:timestamps].to_s
      lines = raw_text.split("\n").map(&:strip)
      lines.pop while lines.last&.empty?

      matches = event.matches.order(:played_at, :id)

      if lines.size != matches.size
        return render json: {
          error: "行数（#{lines.size}）と試合数（#{matches.size}）が一致しません。"
        }, status: :unprocessable_entity
      end

      parsed = lines.map.with_index do |line, i|
        seconds = parse_timestamp(line)
        unless seconds
          return render json: {
            error: "#{i + 1}行目「#{line}」の形式が不正です。H:MM:SS または MM:SS の形式で入力してください。"
          }, status: :unprocessable_entity
        end
        seconds
      end

      ActiveRecord::Base.transaction do
        matches.each_with_index do |match, i|
          match.update!(video_timestamp: parsed[i])
        end
      end

      render json: { message: "OK", updated: matches.size }
    end
  end
end
