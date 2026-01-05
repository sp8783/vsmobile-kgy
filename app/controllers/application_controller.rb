class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Set user_id in cookies for Action Cable authentication
  before_action :set_user_cookie

  # ユーザー視点切り替え機能
  helper_method :viewing_as_user, :viewing_as_someone_else?

  # 現在表示中のユーザー視点を取得
  # 管理者が視点切り替えをしている場合は、そのユーザーを返す
  # それ以外は、ログイン中のユーザーを返す
  def viewing_as_user
    if current_user&.is_admin && session[:view_as_user_id].present?
      User.find_by(id: session[:view_as_user_id]) || current_user
    else
      current_user
    end
  end

  # 視点切り替え中かどうか
  def viewing_as_someone_else?
    current_user&.is_admin && session[:view_as_user_id].present? && session[:view_as_user_id] != current_user.id
  end

  private

  # Set user_id in encrypted cookies for Action Cable
  def set_user_cookie
    if current_user
      cookies.encrypted[:user_id] = current_user.id
    end
  end

  # 管理者権限チェック
  def require_admin
    unless current_user&.is_admin?
      redirect_to root_path, alert: "管理者権限が必要です。"
    end
  end
end
