module Layout
  class UserMenuComponent < ApplicationComponent
    def initialize(current_user:, viewing_as_user:, viewing_as_someone_else:, switchable_users:, placement:)
      @current_user = current_user
      @viewing_as_user = viewing_as_user
      @viewing_as_someone_else = viewing_as_someone_else
      @switchable_users = switchable_users
      @placement = placement
    end

    private

    attr_reader :current_user, :viewing_as_user, :switchable_users, :placement

    def viewing_as_someone_else?
      @viewing_as_someone_else
    end

    def dropdown_classes
      classes(
        "hidden absolute left-0 right-0 z-50 overflow-hidden rounded-lg bg-surface shadow-card",
        placement == :top ? "bottom-full mb-2" : "top-full mt-2"
      )
    end

    def avatar_initial
      viewing_as_user&.nickname.to_s.first.presence || "?"
    end
  end
end
