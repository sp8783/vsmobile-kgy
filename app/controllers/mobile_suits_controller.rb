class MobileSuitsController < ApplicationController
  before_action :authenticate_user!

  def index
    suits = MobileSuit.all.order(Arel.sql("position IS NULL, position ASC, cost DESC, name ASC"))

    # シリーズ内でのコスト別グループ: { series => { cost => [suits] } }
    @suits_by_series = suits.group_by(&:series).transform_values do |series_suits|
      series_suits.group_by(&:cost)
    end

    @costs = [ 3000, 2500, 2000, 1500 ]
  end
end
