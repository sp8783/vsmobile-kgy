class PushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh_key, presence: true
  validates :auth_key, presence: true

  scope :stale, -> { where("last_used_at < ?", 30.days.ago) }

  def mark_used!
    touch(:last_used_at)
  end

  def to_web_push_hash
    {
      endpoint: endpoint,
      keys: {
        p256dh: p256dh_key,
        auth: auth_key
      }
    }
  end
end
