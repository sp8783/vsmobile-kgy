module Ui
  class CostBadgeComponent < ApplicationComponent
    VALID_COSTS = [ 3000, 2500, 2000, 1500 ].freeze

    def initialize(cost:, class_name: nil)
      @cost = cost.to_i
      @class_name = class_name
    end

    private

    attr_reader :cost, :class_name

    def badge_classes
      classes("cost-badge", "cost-badge-#{VALID_COSTS.include?(cost) ? cost : 2000}", class_name)
    end
  end
end
