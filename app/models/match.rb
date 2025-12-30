class Match < ApplicationRecord
  # Associations
  belongs_to :event
  belongs_to :rotation_match, optional: true
  has_many :match_players, dependent: :destroy

  accepts_nested_attributes_for :match_players

  # Validations
  validates :played_at, presence: true
  validates :winning_team, presence: true, inclusion: { in: [1, 2] }
  validates :match_players, length: { is: 4 }

  # イベント内での試合番号を取得（古い順に1から採番）
  def match_number
    event.matches.where('played_at < ?', played_at).count + 1
  end
end
