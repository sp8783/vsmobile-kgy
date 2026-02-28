class Match < ApplicationRecord
  # Associations
  belongs_to :event
  belongs_to :rotation_match, optional: true
  has_many :match_players, dependent: :destroy
  has_many :reactions, dependent: :destroy
  has_one :match_timeline, dependent: :destroy

  accepts_nested_attributes_for :match_players

  # Scopes
  scope :by_latest,           -> { order(played_at: :desc, id: :desc) }
  scope :by_reactions,        -> { order(reactions_count: :desc, played_at: :desc, id: :desc) }
  scope :by_reactions_oldest, -> { order(reactions_count: :desc, played_at: :asc, id: :asc) }
  scope :by_oldest,           -> { order(played_at: :asc, id: :asc) }

  # Validations
  validates :played_at, presence: true
  validates :winning_team, presence: true, inclusion: { in: [ 1, 2 ] }
  validates :match_players, length: { is: 4 }

  # イベント内での試合番号を取得（古い順に1から採番）
  def match_number
    event.matches.where("played_at < ?", played_at).count + 1
  end

  # 特定のユーザーが特定の絵文字でリアクションしているかどうか
  def reacted_by?(user, master_emoji)
    return false unless user
    if reactions.loaded?
      reactions.any? { |r| r.user_id == user.id && r.master_emoji_id == master_emoji.id }
    else
      reactions.exists?(user: user, master_emoji: master_emoji)
    end
  end

  # 特定の絵文字のリアクション数を取得
  def reaction_count(master_emoji)
    if reactions.loaded?
      reactions.count { |r| r.master_emoji_id == master_emoji.id }
    else
      reactions.where(master_emoji: master_emoji).count
    end
  end

  # H:MM:SS形式でのタイムスタンプ入出力用
  def video_timestamp_text
    return "" if video_timestamp.nil?
    h, remainder = video_timestamp.divmod(3600)
    m, s = remainder.divmod(60)
    "#{h}:#{format('%02d', m)}:#{format('%02d', s)}"
  end

  def video_timestamp_text=(text)
    if text.blank?
      self.video_timestamp = nil
      return
    end
    parts = text.strip.split(":").map(&:to_i)
    self.video_timestamp = case parts.size
    when 3 then parts[0] * 3600 + parts[1] * 60 + parts[2]
    when 2 then parts[0] * 60 + parts[1]
    end
  end

  # アーカイブ動画の再生URLを生成
  def video_url
    return nil unless video_timestamp.present? && event.broadcast_url.present?

    base_url = event.broadcast_url
    separator = base_url.include?("?") ? "&" : "?"
    "#{base_url}#{separator}t=#{video_timestamp}s"
  end

  # 特定の絵文字でリアクションしたユーザーのニックネームを取得
  def reaction_user_nicknames(master_emoji)
    if reactions.loaded?
      reactions.select { |r| r.master_emoji_id == master_emoji.id }.map { |r| r.user.nickname }
    else
      reactions.where(master_emoji: master_emoji).includes(:user).map { |r| r.user.nickname }
    end
  end
end
