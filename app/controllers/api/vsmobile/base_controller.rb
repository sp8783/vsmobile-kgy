module Api
  module Vsmobile
    # VS.モバイル連携の API。web.vsmobile.jp 上で動くブックマークレット（public/vsm/collect.js）から、
    # 本人用の鍵（User#vsmobile_token。ブックマークの URL に埋めてある）を Bearer トークンとして受け取る。
    # 別オリジンからの POST なので CSRF はなく、CORS は config/initializers/cors.rb
    class BaseController < ActionController::API
      include ActionController::RateLimiting

      # 鍵が漏れたときの備え。ふだんの送信（対象の確認 1 回 + 試合ごとに 1 回）には届かない数
      rate_limit to: 60, within: 1.minute,
                 by: -> { request.headers["Authorization"].to_s.presence || request.remote_ip },
                 with: -> { render json: { error: "送信が多すぎます。少し待ってから、もう一度押してください。" }, status: :too_many_requests }

      before_action :authenticate_vsmobile_token!

      private

      attr_reader :current_user

      def authenticate_vsmobile_token!
        token = request.headers["Authorization"].to_s.sub(/\ABearer /, "").strip
        @current_user = token.present? ? User.non_guest.find_by(vsmobile_token: token) : nil
        return render json: { error: "連携 URL が無効です。アプリの「設定」で作り直してください。" }, status: :unauthorized unless @current_user

        @current_user.update_column(:vsmobile_token_used_at, Time.current)
      end
    end
  end
end
