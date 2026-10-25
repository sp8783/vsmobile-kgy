# ブックマークレットから届いた試合ページの HTML を解析できなかった・試合に対応づけられなかった記録。
# ブックマークレットは参加者のブラウザで動くので管理者は再現できない。何が届いたかを残し、手元（bin/db-pull）で解析を直したり fixture にしたりする。
# 成功した送信の HTML は残さない（1 件あたり数百 KB あるため。取り込んだデータは MatchStatsPayload にある）
class VsmobileParseFailure < ApplicationRecord
  # VS.モバイルの対戦履歴の保持期間と同じ。これより古い記録は新しい記録を残すときに消す
  RETENTION_DAYS = 30

  belongs_to :user, optional: true
  belongs_to :event, optional: true

  validates :error_message, presence: true
  validates :html, presence: true

  # 同じ人・同じ試合（match_ts）の再送は上書きして、件数が膨らまないようにする。
  # 記録に失敗しても呼び出し側のエラー応答を邪魔しない（ログに残して nil）
  def self.record(user:, event:, match_ts:, error:, request_params:, html:)
    failure = find_or_initialize_by(user: user, event: event, match_ts: match_ts)
    failure.update!(error_message: error.message.truncate(255), request_params: request_params, html: html)
    where(updated_at: ...RETENTION_DAYS.days.ago).delete_all
    failure
  rescue StandardError => e
    Rails.logger.error("VsmobileParseFailure: 記録できませんでした (#{e.class}: #{e.message})")
    nil
  end

  def sender_name
    user&.nickname || "退会した人"
  end
end
