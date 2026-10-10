class Event < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :held_on, presence: true
  validates :broadcast_url, format: { with: /\Ahttps?:\/\//i, message: "は http:// または https:// で始まる URL を入力してください" }, allow_blank: true
  validates :discord_thread_url, format: { with: /\Ahttps?:\/\//i, message: "は http:// または https:// で始まる URL を入力してください" }, allow_blank: true

  # Associations
  has_many :matches, dependent: :destroy
  has_many :rotations, dependent: :destroy

  # Discord フォーラムスレッド URL（https://discord.com/channels/{サーバー}/{スレッド}）からスレッドの ID を取り出す
  def discord_thread_id
    discord_thread_url.to_s[%r{\Ahttps://(?:ptb\.|canary\.)?discord(?:app)?\.com/channels/\d+/(\d+)}, 1]
  end
end
