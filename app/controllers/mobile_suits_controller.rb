class MobileSuitsController < ApplicationController
  before_action :authenticate_user!

  COSTS = [ 3000, 2500, 2000, 1500 ].freeze

  def index
    @counts_by_cost = MobileSuit.group(:cost).count
    @selected_cost = params[:cost].to_i.in?(COSTS) ? params[:cost].to_i : nil
    @suits = @selected_cost ? MobileSuit.where(cost: @selected_cost).order(:position) : MobileSuit.all.order(:position)
    @search_query = params[:q].to_s.strip
  end
end
