class MatchTimeline < ApplicationRecord
  belongs_to :match

  validates :timeline_raw, presence: true
  validate :timeline_raw_must_be_hash

  private

  def timeline_raw_must_be_hash
    return if timeline_raw.is_a?(Hash)
    errors.add(:timeline_raw, "は有効なJSON形式ではありません")
  end
end
