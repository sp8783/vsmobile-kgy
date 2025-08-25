class Match < ApplicationRecord
  belongs_to :event
  belongs_to :team1, class_name: "Team"
  belongs_to :team2, class_name: "Team"
  belongs_to :winner_team, class_name: "Team", optional: true

  has_many :match_players, dependent: :destroy

  validates :team1, presence: true
  validates :team2, presence: true
  validate :different_teams

  private

  def different_teams
    if team1_id.present? && team2_id.present? && team1_id == team2_id
      errors.add(:base, "同じチームを選ぶことはできません")
    end
  end
end
