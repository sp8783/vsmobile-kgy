require "net/http"

class DiscordWebhookService
  class << self
    def post(purpose:, message:)
      channel = DiscordChannel.find_by(purpose: purpose)
      return if channel&.webhook_url.blank?

      uri = URI(channel.webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      req = Net::HTTP::Post.new(uri, { "Content-Type" => "application/json" })
      req.body = { content: message }.to_json
      http.request(req)
    rescue => e
      Rails.logger.error("[DiscordWebhookService] Failed to post (purpose=#{purpose}): #{e.message}")
    end
  end
end
