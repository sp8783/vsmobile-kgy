class MyPageController < ApplicationController
  before_action :authenticate_user!

  COSTS = [ 3000, 2500, 2000, 1500 ].freeze

  def show
    @favorites_by_slot = viewing_as_user.user_favorite_suits
                                     .includes(:mobile_suit)
                                     .index_by(&:slot)
    @selected_suit_ids = UserFavoriteSuit::SLOTS.filter_map { |s| @favorites_by_slot[s]&.mobile_suit_id }
    # 並び替えモードの「使用回数順」用。本人がその機体で戦った全期間の試合数
    @favorite_usage_counts = MatchPlayer.where(user: viewing_as_user, mobile_suit_id: @selected_suit_ids)
                                        .group(:mobile_suit_id)
                                        .count

    @all_suits      = MobileSuit.position_order
    @costs          = COSTS
    @counts_by_cost = MobileSuit.group(:cost).count

    @favorite_matches = viewing_as_user.favorited_matches
                                       .by_latest
                                       .includes(:event, match_players: [ :user, :mobile_suit ])
                                       .page(params[:fav_page])
                                       .per(10)
  end
end
