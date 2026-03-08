class UserFavoriteSuitsController < ApplicationController
  before_action :authenticate_user!

  def bulk_update
    ids = Array(params[:mobile_suit_ids]).map(&:to_i).first(UserFavoriteSuit::MAX_SLOTS)
    valid_ids = MobileSuit.where(id: ids).pluck(:id)
    ordered_ids = ids.select { |id| valid_ids.include?(id) }

    ActiveRecord::Base.transaction do
      current_user.user_favorite_suits.delete_all
      ordered_ids.each_with_index do |suit_id, slot|
        current_user.user_favorite_suits.create!(mobile_suit_id: suit_id, slot: slot)
      end
    end

    redirect_to my_page_path, notice: "お気に入り機体を更新しました"
  end
end
