require "net/http"

class DiscordWebhookService
  class << self
    # 投稿できたら true（投稿先が未設定・失敗なら false）。
    # thread_id を渡すと、Webhook のチャンネル内のスレッド（フォーラムの記事など）に投稿する
    def post(purpose:, message:, thread_id: nil)
      channel = DiscordChannel.find_by(purpose: purpose)
      return false if channel&.webhook_url.blank?

      response = post_to_webhook_url(url: webhook_url_for(channel.webhook_url, thread_id: thread_id), message: message)
      response.is_a?(Net::HTTPSuccess)
    rescue => e
      Rails.logger.error("[DiscordWebhookService] Failed to post (purpose=#{purpose}): #{e.message}")
      false
    end

    def webhook_url_for(url, thread_id: nil)
      return url if thread_id.blank?

      uri = URI(url)
      uri.query = URI.encode_www_form(URI.decode_www_form(uri.query.to_s) + [ [ "thread_id", thread_id ] ])
      uri.to_s
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
