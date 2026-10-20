# 統計・タイムスタンプがそろったイベントについて、Discord のフォーラムの記事に知らせる（EventDataAnnouncer.announce_later から積まれる）
class AnnounceEventDataJob < ApplicationJob
  queue_as :default

  def perform(event_id)
    event = Event.find_by(id: event_id)
    return unless event

    EventDataAnnouncer.new(event: event).announce!
  end
end
