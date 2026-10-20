# イベントの統計・タイムスタンプが全試合そろったら、イベントの Discord フォーラムの記事（Event#discord_thread_url）に
# 「登録しました」と知らせる。1 イベントにつき統計 1 回・タイムスタンプ 1 回まで（知らせた時刻を events に記録する）。
#
# 文面は管理画面の「Discord 投稿文」の「登録の連絡」（DiscordNotice）。初期設定は対戦履歴のリンクだけで時刻そのものは書かない
# （あとでタイムスタンプを直しても投稿が間違いにならない）
class EventDataAnnouncer
  KINDS = %w[stats timestamps].freeze
  LABELS = DiscordNotice::REGISTERED_LABELS

  Result = Struct.new(:posted?, :kinds, :error_message, keyword_init: true)

  # 登録のあとに呼ぶ。まだ知らせていないものがそろっていれば、バックグラウンドで知らせる
  def self.announce_later(event)
    announcer = new(event: event)
    AnnounceEventDataJob.perform_later(event.id) if announcer.can_post? && announcer.pending_kinds.any?
  end

  def initialize(event:, poster: DiscordWebhookService.method(:post))
    @event = event
    @poster = poster
  end

  def notice
    @notice ||= DiscordNotice.for("data_registered")
  end

  # 「登録の連絡」が送る設定で、イベントにスレッド URL が入っているか
  def can_post?
    notice.enabled? && event.discord_thread_id.present?
  end

  # 全試合そろっているのに、まだ知らせていないもの
  def pending_kinds
    KINDS.select { |kind| complete?(kind) && announced_at(kind).nil? }
  end

  def announced_at(kind)
    event.public_send("#{kind}_announced_at")
  end

  def announced_kinds
    KINDS.select { |kind| announced_at(kind).present? }
  end

  def complete?(kind)
    total = event.matches.count
    return false if total.zero?

    registered =
      case kind
      when "stats" then event.matches.joins(:match_timeline).count
      when "timestamps" then event.matches.where.not(video_timestamp: nil).count
      end
    registered == total
  end

  # まだ知らせていないものをまとめて 1 回で知らせ、投稿できたら知らせた時刻を記録する
  def announce!
    return Result.new(posted?: false, kinds: [], error_message: "「登録の連絡」は送らない設定です。Discord 設定の「投稿文」で変えられます。") unless notice.enabled?
    return Result.new(posted?: false, kinds: [], error_message: "Discord フォーラムスレッド URL が入っていません。イベントの「編集」で入れてください。") if event.discord_thread_id.blank?

    result = nil
    event.with_lock do
      kinds = pending_kinds
      if kinds.empty?
        result = Result.new(posted?: false, kinds: [], error_message: "Discord に知らせるものがありません。")
      elsif poster.call(purpose: notice.purpose, message: message(kinds), thread_id: event.discord_thread_id)
        now = Time.current
        event.update!(kinds.to_h { |kind| [ "#{kind}_announced_at", now ] })
        result = Result.new(posted?: true, kinds: kinds)
      else
        result = Result.new(posted?: false, kinds: kinds, error_message: "Discord への投稿に失敗しました。「イベントフォーラム」の投稿先の設定を確認してください。")
      end
    end
    result
  end

  def message(kinds)
    notice.registration_message_for(event, kinds, event_url: event_url)
  end

  def labels(kinds)
    DiscordNotice.registered_label(kinds)
  end

  private

  attr_reader :event, :poster

  def event_url
    Rails.application.routes.url_helpers.event_url(event, **Rails.application.config.action_mailer.default_url_options)
  end
end
