module Ui
  class StatComponent < ApplicationComponent
    TONES = {
      neutral: "text-ink",
      accent: "text-accent",
      danger: "text-neg",
      muted: "text-muted"
    }.freeze

    def initialize(label:, value:, tone: :neutral, suffix: nil, unit: nil, meta: nil, class_name: nil)
      @label = label
      @value = value
      @tone = tone
      @suffix = suffix || unit
      @meta = meta
      @class_name = class_name
    end

    private

    attr_reader :label, :value, :tone, :suffix, :meta, :class_name

    def value_classes
      classes("ui-stat-value", TONES.fetch(tone, TONES[:neutral]))
    end
  end
end
