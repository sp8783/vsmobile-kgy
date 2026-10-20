# 試合の開始時刻から計算したタイムスタンプ（Match#video_timestamp）と、
# 動画解析のタイムスタンプ（Match#analysis_video_timestamp）を試合ごとに比べる。
# 差は「match_ts が VS 画面のどこで記録されるか」の揺れで決まり、VS 画面の長さ（最長 20 秒）より大きくならないため、
# それに余裕を足した 25 秒以上を「違い」とみなす
class EventTimestampComparison
  THRESHOLD = 25

  Difference = Data.define(:match_number, :seconds)

  def initialize(event:)
    @event = event
  end

  # 両方のタイムスタンプがある試合の差（動画解析 − 計算）。試合番号つき
  def differences
    @differences ||= event.matches.order(:played_at, :id).each_with_index.filter_map do |match, index|
      next unless match.video_timestamp && match.analysis_video_timestamp

      Difference.new(match_number: index + 1, seconds: match.analysis_video_timestamp - match.video_timestamp)
    end
  end

  # 計算したタイムスタンプ（1試合目の配信上の時刻と全試合の開始時刻がそろっている）と動画解析のタイムスタンプの両方があるか。
  # 動画解析のタイムスタンプをそのまま登録したときは、比べるものがない
  def comparable?
    EventTimestampCalculator.new(event: event).ready? && differences.any?
  end

  def mismatches
    differences.select { |difference| difference.seconds.abs >= THRESHOLD }
  end

  def median
    sorted = differences.map(&:seconds).sort
    return 0 if sorted.empty?

    middle = sorted.size / 2
    sorted.size.odd? ? sorted[middle] : ((sorted[middle - 1] + sorted[middle]) / 2.0).round
  end

  def max
    differences.map(&:seconds).max_by(&:abs) || 0
  end

  # 通知の文面。例: 「110 試合を比べました。差の中央値 +3 秒・最大 +14 秒。25 秒以上の違い: なし」
  def summary
    mismatch_text = mismatches.any? ? mismatches.map { |m| "第#{m.match_number}試合（#{format_seconds(m.seconds)}）" }.join("、") : "なし"
    "#{differences.size} 試合を比べました。差の中央値 #{format_seconds(median)}・最大 #{format_seconds(max)}。#{THRESHOLD} 秒以上の違い: #{mismatch_text}"
  end

  private

  attr_reader :event

  def format_seconds(seconds)
    format("%+d 秒", seconds)
  end
end
