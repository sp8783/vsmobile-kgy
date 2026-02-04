class SendPushNotificationJob < ApplicationJob
  queue_as :default

  retry_on Net::OpenTimeout, wait: 10.seconds, attempts: 3
  retry_on Net::ReadTimeout, wait: 10.seconds, attempts: 3

  def perform(user_id:, title:, body:, path: "/", icon: "/icon-192.png")
    user = User.find_by(id: user_id)
    return unless user

    subscriptions = user.push_subscriptions
    return if subscriptions.empty?

    payload = build_payload(title, body, path, icon)

    subscriptions.each do |subscription|
      send_notification(subscription, payload)
    end
  end

  private

  def build_payload(title, body, path, icon)
    {
      title: title,
      options: {
        body: body,
        icon: icon,
        badge: "/favicon-32.png",
        data: {
          path: path
        },
        requireInteraction: true,
        tag: "vsmobile-notification-#{Time.current.to_i}"
      }
    }.to_json
  end

  def send_notification(subscription, payload)
    WebPush.payload_send(
      message: payload,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh_key,
      auth: subscription.auth_key,
      vapid: vapid_options
    )

    subscription.mark_used!

  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription => e
    Rails.logger.info "Removing invalid subscription: #{subscription.id} - #{e.message}"
    subscription.destroy

  rescue WebPush::ResponseError => e
    Rails.logger.error "Push notification failed for subscription #{subscription.id}: #{e.message}"
    raise if e.response.code.to_i >= 500
  end

  def vapid_options
    {
      subject: "mailto:#{Rails.application.credentials.dig(:vapid, :subject_email) || 'admin@example.com'}",
      public_key: Rails.application.credentials.dig(:vapid, :public_key),
      private_key: Rails.application.credentials.dig(:vapid, :private_key)
    }
  end
end
