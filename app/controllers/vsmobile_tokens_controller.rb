# VS.モバイル連携の鍵（ブックマークレットの URL に埋める本人用の鍵）を作る・作り直す
class VsmobileTokensController < ApplicationController
  before_action :authenticate_user!

  def create
    return redirect_to root_path, alert: "ゲストユーザーは VS.モバイル連携を使えません。" if current_user.is_guest || current_user.username == "guest"

    had_token = current_user.vsmobile_token.present?
    current_user.regenerate_vsmobile_token!
    redirect_to edit_profile_path(anchor: "vsmobile"),
                notice: had_token ? "連携 URL を作り直しました。古い URL のブックマークは使えなくなるので、新しい URL に貼り替えてください。" : "連携 URL を作りました。"
  end
end
