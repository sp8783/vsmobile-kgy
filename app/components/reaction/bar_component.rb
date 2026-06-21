class Reaction::BarComponent < ApplicationComponent
  def initialize(match:, emojis:, current_user:, can_react:)
    @match = match
    @emojis = emojis
    @current_user = current_user
    @can_react = can_react
  end

  private

  attr_reader :match, :emojis, :current_user, :can_react
end
