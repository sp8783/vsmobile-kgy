require "net/http"

class DiscordWebhookService
  class << self
    # 投稿できたら true（投稿先が未設定・失敗なら false）
    def post(purpose:, message:)
      channel = DiscordChannel.find_by(purpose: purpose)
      return false if channel&.webhook_url.blank?

      response = post_to_webhook_url(url: channel.webhook_url, message: message)
      response.is_a?(Net::HTTPSuccess)
    rescue => e
      Rails.logger.error("[DiscordWebhookService] Failed to post (purpose=#{purpose}): #{e.message}")
      false
    end

    def post_to_webhook_url(url:, message:)
      return if url.blank?

      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      req = Net::HTTP::Post.new(uri, { "Content-Type" => "application/json" })
      req.body = { content: message }.to_json
      http.request(req)
    rescue => e
      Rails.logger.error("[DiscordWebhookService] Failed to post_to_webhook_url (url=#{url}): #{e.message}")
    end
  end
end
