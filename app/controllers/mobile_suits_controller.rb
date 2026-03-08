class MobileSuitsController < ApplicationController
  before_action :authenticate_user!

  COSTS = [ 3000, 2500, 2000, 1500 ].freeze

  def index
    @selected_cost = params[:cost].to_i.in?(COSTS) ? params[:cost].to_i : 3000
    @suits = MobileSuit.where(cost: @selected_cost).order(:id)
    @counts_by_cost = MobileSuit.group(:cost).count
  end
end
