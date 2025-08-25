class Team < ApplicationRecord
  belongs_to :player1, class_name: "User"
  belongs_to :player2, class_name: "User"

  has_many :matches_as_team1, class_name: "Match", foreign_key: "team1_id", dependent: :destroy
  has_many :matches_as_team2, class_name: "Match", foreign_key: "team2_id", dependent: :destroy

  validates :player1, presence: true
  validates :player2, presence: true
  validate :unique_team_combination

  before_validation :normalize_player_order
  before_validation :set_default_name, if: -> { name.blank? && player1 && player2 }

  private

  # player1_id < player2_id に自動で並べ替え
  def normalize_player_order
    return if player1_id.blank? || player2_id.blank?

    if player1_id > player2_id
      self.player1_id, self.player2_id = player2_id, player1_id
    end
  end

  # (player1_id, player2_id) の組み合わせはユニーク
  def unique_team_combination
    return if player1_id.blank? || player2_id.blank?

    if Team.where(player1_id: player1_id, player2_id: player2_id).where.not(id: id).exists?
      errors.add(:base, "このチームは既に存在します")
    end
  end

  # チーム名が決まっていない場合はデフォルトのチーム名を設定
  def set_default_name
    self.name = "NO_NAME_TAG"
  end
end
