module Ui
  class CardComponent < ApplicationComponent
    def initialize(title: nil, subtitle: nil, actions: nil, padded: true, tone: :default, class_name: nil)
      @title = title
      @subtitle = subtitle
      @actions = actions
      @padded = padded
      @tone = tone
      @class_name = class_name
    end

    private

    attr_reader :title, :subtitle, :actions, :padded, :tone, :class_name

    def card_classes
      classes(tone == :soft ? "ui-card-soft" : "ui-card", padded && "ui-card-pad", class_name)
    end
  end
end
