module Layout
  class ShellComponent < ApplicationComponent
    def initialize(user_signed_in:, current_user:, viewing_as_user:, viewing_as_someone_else:, unread_announcement:, flash:)
      @user_signed_in = user_signed_in
      @current_user = current_user
      @viewing_as_user = viewing_as_user
      @viewing_as_someone_else = viewing_as_someone_else
      @unread_announcement = unread_announcement
      @flash = flash
    end

    private

    attr_reader :current_user, :viewing_as_user, :unread_announcement, :flash

    def user_signed_in?
      @user_signed_in
    end

    def viewing_as_someone_else?
      @viewing_as_someone_else
    end

    def switchable_users
      return User.none unless current_user&.is_admin?

      User.where(is_admin: false).order(:nickname)
    end
  end
end
