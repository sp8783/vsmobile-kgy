class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :rememberable, :validatable

  # Associations
  has_many :match_players, dependent: :destroy
  has_many :user_favorite_suits, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  has_many :reactions, dependent: :destroy
  has_many :user_announcement_reads, dependent: :destroy
  has_many :read_announcements, through: :user_announcement_reads, source: :announcement
  has_many :favorite_matches, dependent: :destroy
  has_many :favorited_matches, through: :favorite_matches, source: :match

  # 対戦結果入力のプルダウンの先頭に出す、最近使った機体の数
  RECENT_MOBILE_SUITS_LIMIT = 10

  # Validations
  validates :username, presence: true, uniqueness: { case_sensitive: false },
            format: { with: /\A[a-zA-Z0-9_-]+\z/, message: "は半角英数字と記号（_ -）のみ使用できます" }
  validates :nickname, presence: true

  # Scopes
  scope :regular_users, -> { where(is_admin: false, is_guest: false) }
  scope :non_guest, -> { where(is_guest: false) }

  # 一般ユーザー（管理者でもゲストでもない）かどうか
  def regular_user?
    !is_admin && !is_guest
  end

  # Virtual email attribute (maps to username for Devise compatibility)
  def email
    username
  end

  def email=(value)
    self.username = value
  end

  # Override Devise's email validation (we use username instead)
  def email_required?
    false
  end

  def email_changed?
    false
  end

  def will_save_change_to_email?
    false
  end

  # 試合で使った機体を、最後に使った日時の新しい順に重複なく返す（お気に入りは画像のボタンで選べるため除く）
  def recent_mobile_suit_ids(limit: RECENT_MOBILE_SUITS_LIMIT)
    match_players.joins(:match)
      .where.not(mobile_suit_id: user_favorite_suits.select(:mobile_suit_id))
      .group(:mobile_suit_id)
      .order(Arel.sql("MAX(matches.played_at) DESC, MAX(matches.id) DESC"))
      .limit(limit)
      .pluck(:mobile_suit_id)
  end

  # Check if user can receive push notifications
  def push_notifications_enabled?
    push_subscriptions.exists?
  end

  # Use username for authentication instead of email
  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    if (login = conditions.delete(:email))
      where(conditions).find_by(username: login.downcase)
    else
      where(conditions).first
    end
  end
end
