# 試合の統計を取り込んだあとの共通の後処理（一括取得と VS.モバイル連携の両方から呼ぶ）。
# 1 試合目の配信上の時刻が入っていて全試合の開始時刻がそろえば、全試合のタイムスタンプを計算する。
# 動画解析のタイムスタンプが先に届いていれば、あわせて比べる。統計・タイムスタンプが全試合そろえば Discord に知らせる
class EventStatsFollowUp
  def self.call(event)
    new(event: event).call
  end

  def initialize(event:)
    @event = event
  end

  def call
    timestamp_count = EventTimestampCalculator.new(event: event).apply!
    if timestamp_count
      PushNotificationService.notify_timestamps_registered(event: event, count: timestamp_count)
      comparison = EventTimestampComparison.new(event: event)
      PushNotificationService.notify_timestamps_compared(event: event, summary: comparison.summary) if comparison.comparable?
    end
    EventDataAnnouncer.announce_later(event)
  end

  private

  attr_reader :event
end
