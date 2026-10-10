# 毎時実行し、管理画面の「Discord 投稿文」で設定した時刻のタイミングの投稿を送る。
# 同じイベント・同じ日数の投稿は一度だけ送る（時刻の設定を変えても二重に送らない）
class EventReminderJob < ApplicationJob
  queue_as :default

  # now / poster: テストで差し替えられるようにする
  def perform(now: Time.current, poster: DiscordWebhookService.method(:post))
    # DiscordNotice::KINDS の順（事前準備のお願い → リマインド）に送る
    DiscordNotice::KINDS.map { |kind| DiscordNotice.for(kind) }.select(&:enabled?).each do |notice|
      notice.timing_list.select { |timing| timing.hour == now.hour }.each do |timing|
        Event.where(held_on: now.to_date + timing.days_before).order(:id).each do |event|
          deliver(notice, event, timing.days_before, poster)
        end
      end
    end
  end

  private

  def deliver(notice, event, days_before, poster)
    return if DiscordNoticeDelivery.exists?(event: event, kind: notice.kind, days_before: days_before)

    # 事前準備のお願いはイベントのフォーラム記事に投稿する。記事が未登録なら送らない
    thread_id = event.discord_thread_id if notice.preparation?
    return if notice.preparation? && thread_id.nil?

    message = notice.message_for(event, days_before)
    return if message.blank?

    posted = poster.call(purpose: notice.purpose, message: message, thread_id: thread_id)
    DiscordNoticeDelivery.create!(event: event, kind: notice.kind, days_before: days_before, sent_at: Time.current) if posted
  end
end
