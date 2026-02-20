class Announcement < ApplicationRecord
  has_many :user_announcement_reads, dependent: :destroy
  has_many :read_by_users, through: :user_announcement_reads, source: :user

  validates :title, presence: true
  validates :body, presence: true
  validates :published_at, presence: true

  scope :active, -> {
    where(is_active: true)
      .where("published_at <= ?", Time.current)
      .where("expires_at IS NULL OR expires_at >= ?", Time.current)
      .order(published_at: :desc)
  }

  def read_by?(user)
    user_announcement_reads.exists?(user: user)
  end
end
