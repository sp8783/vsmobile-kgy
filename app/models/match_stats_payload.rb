# 統計スクレイピング（exvs2ib-vsmobile-scraper）で届いた試合ごとのデータ。
# 今後何が必要になるかわからないため、加工せずにそのまま残す（VS.モバイルの対戦履歴は過去 30 日分しか残らない）
class MatchStatsPayload < ApplicationRecord
  belongs_to :match

  validates :payload, presence: true
end
