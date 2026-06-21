module Layout
  class TopbarComponent < ApplicationComponent
    include Navigation

    def initialize(current_user:, viewing_as_user:, viewing_as_someone_else:, switchable_users:)
      @current_user = current_user
      @viewing_as_user = viewing_as_user
      @viewing_as_someone_else = viewing_as_someone_else
      @switchable_users = switchable_users
    end

    private

    attr_reader :current_user, :viewing_as_user, :switchable_users

    def viewing_as_someone_else?
      @viewing_as_someone_else
    end
  end
end
