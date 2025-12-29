class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :rememberable, :validatable

  # Validations
  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :nickname, presence: true

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
