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

  protected

  # If you have extra params to permit, append them to the sanitizer.
  def configure_sign_in_params
    devise_parameter_sanitizer.permit(:sign_in, keys: [:username])
  end
end
