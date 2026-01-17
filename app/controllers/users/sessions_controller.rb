class Users::SessionsController < Devise::SessionsController
  before_action :configure_sign_in_params, only: [:create]

  # Set user_id in encrypted cookies for Action Cable authentication
  def create
    super do |resource|
      cookies.encrypted[:user_id] = resource.id
    end
  end

  # Clear user_id from cookies on sign out
  def destroy
    cookies.delete(:user_id)
    super
  end

  # Guest login
  def guest
    guest_user = User.find_or_create_by!(username: 'guest') do |user|
      user.nickname = 'ゲスト'
      user.password = SecureRandom.hex(16)
      user.is_admin = false
      user.is_guest = true
    end

    sign_in(guest_user)
    cookies.encrypted[:user_id] = guest_user.id
    redirect_to root_path, notice: 'ゲストとしてログインしました。'
  end

  protected

  # If you have extra params to permit, append them to the sanitizer.
  def configure_sign_in_params
    devise_parameter_sanitizer.permit(:sign_in, keys: [:username])
  end
end
