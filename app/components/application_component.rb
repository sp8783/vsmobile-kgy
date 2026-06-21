class ApplicationComponent < ViewComponent::Base
  private

  def classes(*values)
    values.flatten.compact_blank.join(" ")
  end
end
