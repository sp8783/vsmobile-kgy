class PushSubscription < ApplicationRecord
  belongs_to :user

  # Push サービスの endpoint は https の URL だけ（内部ネットワークなど任意の URL に POST させない）
  validates :endpoint, presence: true, uniqueness: true,
                       format: { with: %r{\Ahttps://\S+\z}i, message: "は https:// で始まる URL を指定してください" }
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
