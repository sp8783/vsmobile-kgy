# 統計の取り込み（exvs2ib-vsmobile-scraper の一括取得、または参加者の VS.モバイル連携）で届いた試合ごとのデータ。
# 今後何が必要になるかわからないため、加工せずにそのまま残す（VS.モバイルの対戦履歴は過去 30 日分しか残らない）
class MatchStatsPayload < ApplicationRecord
  belongs_to :match
  # 誰のブックマークレットから届いたか（一括取得は nil）
  belongs_to :submitted_by, class_name: "User", optional: true

  validates :payload, presence: true
end
