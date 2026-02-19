module Api
  class BaseController < ActionController::API
    before_action :authenticate_api_token!

    private

    def authenticate_api_token!
      token = request.headers["Authorization"]&.sub(/\ABearer /, "")
      api_token = ENV["TIMESTAMP_API_TOKEN"].presence

      if api_token.blank? || token != api_token
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
