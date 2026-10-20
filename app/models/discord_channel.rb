class DiscordChannel < ApplicationRecord
  PURPOSES = %w[reminder event_forum broadcast_url release].freeze

  PURPOSE_LABELS = {
    "reminder"      => "イベントリマインド",
    "event_forum"   => "イベントフォーラム",
    "broadcast_url" => "配信URL投稿",
    "release"       => "リリース告知"
  }.freeze

  PURPOSE_HINTS = {
    "event_forum" => "フォーラムのチャンネルで作った Webhook を設定します。イベントの「Discord フォーラムスレッド URL」の記事へ、前日に事前準備のお願いを、対戦会のあとに統計・タイムスタンプを登録したことを投稿します。"
  }.freeze

  validates :purpose, presence: true, inclusion: { in: PURPOSES }, uniqueness: true

  def purpose_label
    PURPOSE_LABELS[purpose] || purpose
  end

  def purpose_hint
    PURPOSE_HINTS[purpose]
  end
end
