class Event < ApplicationRecord
  has_many :matches, dependent: :destroy

  validates :name, presence: true
  validates :date, presence: true
  validates :event_type, inclusion: { in: %w[オンライン オフライン],
                                      message: "%{value}は無効なイベント形式です" }
end
