class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :rememberable, :validatable

  # Associations
  has_many :match_players, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  has_many :reactions, dependent: :destroy

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
