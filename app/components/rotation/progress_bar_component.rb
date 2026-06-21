class Rotation::ProgressBarComponent < ApplicationComponent
  def initialize(current:, total:)
    @current = current.to_i
    @total = total.to_i
  end

  private

  attr_reader :current, :total
end
