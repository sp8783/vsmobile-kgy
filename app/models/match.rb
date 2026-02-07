class Match < ApplicationRecord
  # Associations
  belongs_to :event
  belongs_to :rotation_match, optional: true
  has_many :match_players, dependent: :destroy
  has_many :reactions, dependent: :destroy

  accepts_nested_attributes_for :match_players

  # Validations
  validates :played_at, presence: true
  validates :winning_team, presence: true, inclusion: { in: [1, 2] }
  validates :match_players, length: { is: 4 }

  # イベント内での試合番号を取得（古い順に1から採番）
  def match_number
    event.matches.where('played_at < ?', played_at).count + 1
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

  # 特定の絵文字でリアクションしたユーザーのニックネームを取得
  def reaction_user_nicknames(master_emoji)
    if reactions.loaded?
      reactions.select { |r| r.master_emoji_id == master_emoji.id }.map { |r| r.user.nickname }
    else
      reactions.where(master_emoji: master_emoji).includes(:user).map { |r| r.user.nickname }
    end
  end
end
