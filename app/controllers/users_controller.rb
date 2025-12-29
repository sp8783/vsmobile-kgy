class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_user, only: [:edit, :update, :destroy]

  def index
    @users = User.all.order(:username)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.password = params[:user][:password]
    @user.password_confirmation = params[:user][:password_confirmation]

    if @user.save
      redirect_to users_path, notice: "ユーザー「#{@user.username}」を作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    user_params_for_update = user_params

    # パスワードが入力されている場合のみ更新
    if params[:user][:password].present?
      user_params_for_update = user_params_for_update.merge(
        password: params[:user][:password],
        password_confirmation: params[:user][:password_confirmation]
      )
      if @user.update(user_params_for_update)
        redirect_to users_path, notice: "ユーザー「#{@user.username}」を更新しました。"
      else
        render :edit, status: :unprocessable_entity
      end
    else
      # パスワードなしで更新
      if @user.update_without_password(user_params_for_update)
        redirect_to users_path, notice: "ユーザー「#{@user.username}」を更新しました。"
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    if @user.id == current_user.id
      redirect_to users_path, alert: '自分自身を削除することはできません。'
      return
    end

    username = @user.username
    @user.destroy
    redirect_to users_path, notice: "ユーザー「#{username}」を削除しました。"
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:username, :nickname, :is_admin, :notification_enabled)
  end

  def require_admin
    unless current_user.is_admin?
      redirect_to root_path, alert: '管理者権限が必要です。'
    end
  end
end
