class DiscordChannel < ApplicationRecord
  PURPOSES = %w[reminder timestamp_result stats_result broadcast_url].freeze

  PURPOSE_LABELS = {
    "reminder"         => "イベントリマインド",
    "timestamp_result" => "タイムスタンプ解析結果",
    "stats_result"     => "統計スクレイピング結果",
    "broadcast_url"    => "配信URL投稿"
  }.freeze

  validates :purpose, presence: true, inclusion: { in: PURPOSES }, uniqueness: true

  def purpose_label
    PURPOSE_LABELS[purpose] || purpose
  end
end
