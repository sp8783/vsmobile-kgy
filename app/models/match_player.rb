class MatchPlayer < ApplicationRecord
  # Associations
  belongs_to :match
  belongs_to :user
  belongs_to :mobile_suit

  # Validations
  validates :team_number, presence: true, inclusion: { in: [ 1, 2 ] }
  validates :position, presence: true, inclusion: { in: [ 1, 2, 3, 4 ] }
  validates :position, uniqueness: { scope: :match_id }
  validates :match_rank, inclusion: { in: [ 1, 2, 3, 4 ] }, allow_nil: true

  def has_stats?
    score.present? || kills.present? || deaths.present? ||
      damage_dealt.present? || damage_received.present? || exburst_damage.present?
  end
end
