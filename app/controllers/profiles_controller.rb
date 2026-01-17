class ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :reject_guest_user

  def edit
    @user = current_user
  end

  def update
    @user = current_user

    # パスワードが入力されている場合のみ更新
    if params[:user][:password].present?
      if @user.update(profile_params_with_password)
        bypass_sign_in(@user) # パスワード変更後もログイン状態を維持
        redirect_to edit_profile_path, notice: "設定を更新しました。"
      else
        render :edit, status: :unprocessable_entity
      end
    else
      # パスワードなしで更新
      if @user.update_without_password(profile_params)
        redirect_to edit_profile_path, notice: "設定を更新しました。"
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  private

  def reject_guest_user
    if current_user.username == 'guest'
      redirect_to root_path, alert: 'ゲストユーザーは設定を変更できません。'
    end
  end

  def profile_params
    params.require(:user).permit(:nickname, :notification_enabled)
  end

  def profile_params_with_password
    params.require(:user).permit(:nickname, :notification_enabled, :password, :password_confirmation)
  end
end
