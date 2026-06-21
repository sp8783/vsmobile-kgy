module Ui
  class DataTableComponent < ApplicationComponent
    renders_many :headers

    def initialize(class_name: nil)
      @class_name = class_name
    end

    private

    attr_reader :class_name
  end
end
