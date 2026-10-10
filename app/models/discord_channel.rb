class DiscordChannel < ApplicationRecord
  PURPOSES = %w[reminder event_forum timestamp_result stats_result broadcast_url release].freeze

  PURPOSE_LABELS = {
    "reminder"         => "イベントリマインド",
    "event_forum"      => "イベントフォーラム",
    "timestamp_result" => "タイムスタンプ解析結果",
    "stats_result"     => "統計スクレイピング結果",
    "broadcast_url"    => "配信URL投稿",
    "release"          => "リリース告知"
  }.freeze

  PURPOSE_HINTS = {
    "event_forum" => "フォーラムのチャンネルで作った Webhook を設定します。イベントの前日に、イベントの「Discord フォーラムスレッド URL」の記事へ事前準備のお願いを投稿します。"
  }.freeze

  validates :purpose, presence: true, inclusion: { in: PURPOSES }, uniqueness: true

  def purpose_label
    PURPOSE_LABELS[purpose] || purpose
  end

  def purpose_hint
    PURPOSE_HINTS[purpose]
  end
end
