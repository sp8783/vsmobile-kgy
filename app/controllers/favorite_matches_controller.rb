class FavoriteMatchesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_match

  def create
    unless viewing_as_user&.regular_user?
      head :forbidden
      return
    end

    @match.favorite_matches.find_or_create_by!(user: viewing_as_user)
    @is_favorited = true

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to match_path(@match) }
    end
  end

  def destroy
    @match.favorite_matches.find_by(user: viewing_as_user)&.destroy
    @is_favorited = false

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to match_path(@match) }
    end
  end

  private

  def set_match
    @match = Match.find(params[:match_id])
  end
end
