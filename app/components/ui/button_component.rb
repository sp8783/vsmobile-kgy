module Ui
  class ButtonComponent < ApplicationComponent
    VARIANTS = {
      primary: "ui-btn-primary",
      ghost: "ui-btn-ghost",
      muted: "ui-btn-muted",
      danger: "ui-btn-danger"
    }.freeze

    def initialize(label: nil, href: nil, variant: :primary, size: :md, data: {}, method: nil, class_name: nil)
      @label = label
      @href = href
      @variant = variant
      @size = size
      @data = data
      @method = method
      @class_name = class_name
    end

    private

    attr_reader :label, :href, :variant, :size, :data, :method, :class_name

    def button_classes
      classes("ui-btn", VARIANTS.fetch(variant, VARIANTS[:primary]), size == :sm && "ui-btn-small", class_name)
    end
  end
end
