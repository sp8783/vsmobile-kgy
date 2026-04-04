class EventReminderJob < ApplicationJob
  queue_as :default

  def perform
    today = Date.current

    { 1 => "明日", 7 => "1週間後" }.each do |days, label|
      target_date = today + days
      events = Event.where(held_on: target_date)
      next if events.none?

      events.each do |event|
        message = build_message(event, label)
        DiscordWebhookService.post(purpose: :reminder, message: message)
      end
    end
  end

  private

  def build_message(event, label)
    lines = []
    lines << "@everyone"
    lines << "【リマインド】"
    lines << "↓こちら、#{label}の開催です！！"
    lines << event.discord_thread_url if event.discord_thread_url.present?
    lines << "参加したい方はフォーラムまで連絡下さい！！"
    lines.join("\n")
  end
end
