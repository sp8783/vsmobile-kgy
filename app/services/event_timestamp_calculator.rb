# 試合の開始時刻（統計スクレイピングの match_ts）と、1試合目が配信の何秒目か（Event#first_match_video_timestamp）から、
# 全試合のタイムスタンプを計算して登録する。
# 配信の時刻と実際の時刻の差は配信の間ほぼ一定なので、1試合目からの経過秒数を足せば各試合の配信上の時刻になる
class EventTimestampCalculator
  def initialize(event:)
    @event = event
  end

  def matches
    @matches ||= event.matches.order(:played_at, :id).to_a
  end

  # 開始時刻を取り込んだ試合の数
  def started_count
    matches.count { |match| match.game_started_at.present? }
  end

  # 1試合目の配信上の時刻があり、全試合の開始時刻を取り込んでいれば計算できる
  def ready?
    event.first_match_video_timestamp.present? && matches.any? && started_count == matches.size
  end

  # 計算して登録し、登録した試合数を返す。計算できなければ nil
  def apply!
    return unless ready?

    first_started_at = matches.first.game_started_at
    ActiveRecord::Base.transaction do
      matches.each do |match|
        match.update!(video_timestamp: event.first_match_video_timestamp + (match.game_started_at - first_started_at).round)
      end
    end
    matches.size
  end

  private

  attr_reader :event
end
