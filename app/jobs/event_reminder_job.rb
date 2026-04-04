class EventReminderJob < ApplicationJob
  queue_as :default

  PREPARATION_MESSAGE_URL = "https://discord.com/channels/731348521269329971/1483812692023181554/1483813049029623910"

  def perform
    today = Date.current

    { 1 => "明日", 7 => "1週間後" }.each do |days, label|
      target_date = today + days
      events = Event.where(held_on: target_date)
      next if events.none?

      events.each do |event|
        message = build_message(event, label)
        DiscordWebhookService.post(purpose: :reminder, message: message)

        if days == 1 && event.discord_channel_webhook_url.present?
          DiscordWebhookService.post_to_webhook_url(
            url: event.discord_channel_webhook_url,
            message: build_preparation_message
          )
        end
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

  def build_preparation_message
    <<~MSG.chomp
      【事前準備のお願い】

      明日のイベントに向けて、以下の準備をお願いします！
      ・通知設定（ホーム画面に追加 & プッシュ通知ON）
      ・Cookieの共有
      ・お気に入り機体の設定

      準備内容の詳細はこちら↓
      #{PREPARATION_MESSAGE_URL}
    MSG
  end
end
