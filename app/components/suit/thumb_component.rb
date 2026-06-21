module Suit
  class ThumbComponent < ApplicationComponent
    def initialize(suit:, size: :md, class_name: nil)
      @suit = suit
      @size = size
      @class_name = class_name
    end

    private

    attr_reader :suit, :size, :class_name

    def wrapper_classes
      classes("suit-thumb", size_class, class_name)
    end

    def size_class
      case size
      when :lg
        "suit-thumb-lg"
      when :sm
        "suit-thumb-sm"
      else
        "suit-thumb-md"
      end
    end
  end
end
