class EventTimestampBatch
  include TimestampParseable

  Result = Struct.new(:success?, :error_message, :timestamps_text, :updated_count, keyword_init: true)

  def initialize(event:)
    @event = event
  end

  def matches
    @matches ||= event.matches.includes(match_players: [ :user, :mobile_suit ]).order(:played_at, :id)
  end

  def existing_text
    existing = matches.map { |match| format_timestamp(match.video_timestamp) }
    existing.any?(&:present?) ? existing.join("\n") : ""
  end

  def update(raw_text)
    lines = normalized_lines(raw_text)

    return failure_result(raw_text, "行数（#{lines.size}）と試合数（#{matches.size}）が一致しません。") if lines.size != matches.size

    timestamps = parse_lines(lines, raw_text)
    return timestamps if timestamps.is_a?(Result)

    ActiveRecord::Base.transaction do
      matches.each_with_index do |match, index|
        match.update!(video_timestamp: timestamps[index])
      end
    end

    Result.new(success?: true, timestamps_text: raw_text, updated_count: matches.size)
  end

  private

  attr_reader :event

  def normalized_lines(raw_text)
    lines = raw_text.to_s.split("\n").map(&:strip)
    lines.pop while lines.last&.empty?
    lines
  end

  def parse_lines(lines, raw_text)
    lines.map.with_index do |line, index|
      return failure_result(raw_text, "#{index + 1}行目が空です。すべての行にタイムスタンプを入力してください。") if line.blank?

      seconds = parse_timestamp(line)
      return failure_result(raw_text, "#{index + 1}行目「#{line}」の形式が不正です。H:MM:SS または MM:SS の形式で入力してください。") if seconds.nil?

      seconds
    end
  end

  def failure_result(raw_text, message)
    Result.new(success?: false, error_message: message, timestamps_text: raw_text)
  end
end
