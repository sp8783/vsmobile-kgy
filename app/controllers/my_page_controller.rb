class MyPageController < ApplicationController
  before_action :authenticate_user!

  COSTS = [ 3000, 2500, 2000, 1500 ].freeze

  def show
    @favorites_by_slot = viewing_as_user.user_favorite_suits
                                     .includes(:mobile_suit)
                                     .index_by(&:slot)
    @selected_suit_ids = (0..11).filter_map { |s| @favorites_by_slot[s]&.mobile_suit_id }

    @all_suits      = MobileSuit.all.order(:position)
    @costs          = COSTS
    @counts_by_cost = MobileSuit.group(:cost).count

    @favorite_matches = viewing_as_user.favorited_matches
                                       .by_latest
                                       .includes(:event, match_players: [ :user, :mobile_suit ])
                                       .page(params[:fav_page])
                                       .per(10)
  end
end
