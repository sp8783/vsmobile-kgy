# 動画解析（exvs2ib-replay-parser）から届いたタイムスタンプの登録。
#
# - 全試合の開始時刻（統計スクレイピングの match_ts）があれば、動画解析のタイムスタンプは Match#analysis_video_timestamp に残すだけにし、
#   試合の開始時刻から計算したタイムスタンプ（Match#video_timestamp）と比べる。
#   1試合目の配信上の時刻が入っていなければ、動画解析の1試合目の時刻を使って計算する
# - 試合の開始時刻がなければ（統計を取り込む前・取り込みの失敗）、今までどおり動画解析のタイムスタンプをそのまま登録する
class EventAnalysisTimestamps
  Result = Struct.new(:success?, :error_message, :updated_count, :comparison, keyword_init: true)

  def initialize(event:)
    @event = event
  end

  def apply(raw_text)
    batch = EventTimestampBatch.new(event: event)
    timestamps = batch.parse(raw_text)
    return Result.new(success?: false, error_message: timestamps.error_message) if timestamps.is_a?(EventTimestampBatch::Result)

    calculator = EventTimestampCalculator.new(event: event)
    ActiveRecord::Base.transaction do
      batch.matches.each_with_index { |match, index| match.update!(analysis_video_timestamp: timestamps[index]) }

      if calculator.started_count == batch.matches.size
        event.update!(first_match_video_timestamp: timestamps.first) if event.first_match_video_timestamp.nil?
        calculator.apply!
      else
        batch.update(raw_text)
      end
    end

    comparison = EventTimestampComparison.new(event: event)
    Result.new(success?: true, updated_count: batch.matches.size, comparison: comparison.comparable? ? comparison : nil)
  end

  private

  attr_reader :event
end
