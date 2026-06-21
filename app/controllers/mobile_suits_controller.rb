class MobileSuitsController < ApplicationController
  before_action :authenticate_user!

  COSTS = [ 3000, 2500, 2000, 1500 ].freeze

  def index
    @counts_by_cost = MobileSuit.group(:cost).count
    @selected_cost = params[:cost].to_i.in?(COSTS) ? params[:cost].to_i : nil
    @suits = @selected_cost ? MobileSuit.where(cost: @selected_cost).position_order : MobileSuit.position_order
    @search_query = params[:q].to_s.strip
  end

  def show
    @suit = MobileSuit.find(params[:id])
    assign_view_state(MobileSuitStatisticsSnapshot.new(mobile_suit: @suit).to_h)
  end

  private

  def assign_view_state(attributes)
    attributes.each do |name, value|
      instance_variable_set("@#{name}", value)
    end
  end
end
