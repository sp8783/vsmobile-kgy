module Ui
  class TagComponent < ApplicationComponent
    TONES = {
      neutral: nil,
      active: "ui-chip-active",
      accent: "ui-chip-accent",
      danger: "ui-chip-danger"
    }.freeze

    def initialize(label: nil, tone: :neutral, class_name: nil)
      @label = label
      @tone = tone
      @class_name = class_name
    end

    private

    attr_reader :label, :tone, :class_name

    def tag_classes
      classes("ui-chip", TONES.fetch(tone, nil), class_name)
    end
  end
end
