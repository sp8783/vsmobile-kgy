# イベントの Discord 投稿（リマインド・事前準備のお願い・登録の連絡）の文面と送るタイミング。
# 保存されていない種類は DEFAULTS を使う（設定しなければ、これまでと同じ投稿になる）
class DiscordNotice < ApplicationRecord
  # 時刻で送る投稿の送る順。同じ時刻のときは事前準備のお願いを先に送る（記事が復活し、リマインドの記事リンクが「#記事名」で表示される）
  SCHEDULED_KINDS = %w[preparation reminder].freeze
  # 登録の連絡: 統計・タイムスタンプが全試合そろったときに送る（タイミングの設定はない）
  KINDS = (SCHEDULED_KINDS + %w[data_registered]).freeze
  # 管理画面に並べる順
  DISPLAY_KINDS = %w[reminder preparation data_registered].freeze

  KIND_LABELS = { "reminder" => "リマインド", "preparation" => "事前準備のお願い", "data_registered" => "登録の連絡" }.freeze
  # 投稿先（DiscordChannel の purpose）
  PURPOSES = { "reminder" => "reminder", "preparation" => "event_forum", "data_registered" => "event_forum" }.freeze

  DAYS_BEFORE = (1..14).freeze
  HOURS = (0..23).freeze
  BODY_LIMIT = 2000
  WEEKDAYS = %w[日 月 火 水 木 金 土].freeze
  # 差し込み用の文字（時刻で送る投稿・登録の連絡）
  PLACEHOLDERS = %w[{イベント名} {開催日} {いつ} {フォーラムURL}].freeze
  REGISTRATION_PLACEHOLDERS = %w[{イベント名} {登録したものの箇条書き} {登録したもの} {対戦履歴URL}].freeze
  # {登録したもの} に入る言い方（EventDataAnnouncer::KINDS の種類）
  REGISTERED_LABELS = { "stats" => "各試合の統計", "timestamps" => "配信アーカイブのタイムスタンプ" }.freeze

  DEFAULTS = {
    "reminder" => {
      body: <<~BODY.chomp,
        @everyone
        【リマインド】
        ↓こちら、{いつ}の開催です！！
        {フォーラムURL}
        参加したい方はフォーラムまで連絡下さい！！
      BODY
      timings: [ { days_before: 7, hour: 8 }, { days_before: 1, hour: 8 } ]
    },
    "preparation" => {
      body: <<~BODY.chomp,
        【事前準備のお願い】

        {いつ}のイベントに向けて、以下の準備をお願いします！
        ・通知設定（ホーム画面に追加 & プッシュ通知ON）
        ・Cookieの共有
        ・お気に入り機体の設定

        準備内容の詳細はこちら↓
        https://discord.com/channels/731348521269329971/1483812692023181554/1483813049029623910
      BODY
      timings: [ { days_before: 1, hour: 8 } ]
    },
    "data_registered" => {
      body: <<~BODY.chomp,
        {イベント名} の対戦履歴に、次のデータを登録しました。
        {登録したものの箇条書き}

        本イベントの対戦履歴: {対戦履歴URL}
      BODY
      timings: []
    }
  }.freeze

  Timing = Data.define(:days_before, :hour)

  validates :kind, inclusion: { in: KINDS }, uniqueness: true
  validates :body, presence: true, length: { maximum: BODY_LIMIT }
  validate :validate_timings

  def self.for(kind)
    find_by(kind: kind) || new(kind: kind, **DEFAULTS.fetch(kind))
  end

  # {いつ} に入る言い方
  def self.when_label(days_before)
    case days_before
    when 1 then "明日"
    when 7 then "1週間後"
    else "#{days_before}日後"
    end
  end

  def self.format_date(date)
    "#{date.month}/#{date.day}(#{WEEKDAYS[date.wday]})"
  end

  # {登録したもの} に入る言い方（例: 各試合の統計と配信アーカイブのタイムスタンプ）
  def self.registered_label(kinds)
    kinds.map { |kind| REGISTERED_LABELS.fetch(kind) }.join("と")
  end

  # {登録したものの箇条書き} に入る Markdown の箇条書き
  def self.registered_list(kinds)
    kinds.map { |kind| "- #{REGISTERED_LABELS.fetch(kind)}" }.join("\n")
  end

  def body=(value)
    super(value&.gsub("\r\n", "\n"))
  end

  # 管理画面のフォームから来た値（文字列）も、整数のハッシュにそろえて保存する
  def timings=(value)
    super(Array(value).map do |timing|
      timing = timing.to_h.stringify_keys
      { "days_before" => Integer(timing["days_before"], exception: false), "hour" => Integer(timing["hour"], exception: false) }
    end)
  end

  def timing_list
    timings.map { |timing| Timing.new(days_before: timing["days_before"], hour: timing["hour"]) }
  end

  def label
    KIND_LABELS.fetch(kind)
  end

  def purpose
    PURPOSES.fetch(kind)
  end

  def preparation?
    kind == "preparation"
  end

  # 時刻で送る投稿か（登録の連絡は、登録がそろったときに送る）
  def scheduled?
    SCHEDULED_KINDS.include?(kind)
  end

  # イベントの記事に送る投稿か
  def to_thread?
    purpose == "event_forum"
  end

  def placeholders
    scheduled? ? PLACEHOLDERS : REGISTRATION_PLACEHOLDERS
  end

  # 差し込み用の文字をイベントの内容に置き換える（時刻で送る投稿）
  def message_for(event, days_before)
    fill(
      "{イベント名}" => event.name,
      "{開催日}" => self.class.format_date(event.held_on),
      "{いつ}" => self.class.when_label(days_before),
      "{フォーラムURL}" => event.discord_thread_url.presence
    )
  end

  # 差し込み用の文字を登録した内容に置き換える（登録の連絡）。kinds は登録したもの（stats / timestamps）
  def registration_message_for(event, kinds, event_url:)
    fill(
      "{イベント名}" => event.name,
      "{登録したものの箇条書き}" => self.class.registered_list(kinds),
      "{登録したもの}" => self.class.registered_label(kinds),
      "{対戦履歴URL}" => event_url
    )
  end

  private

  # 値が空の差し込みを含む行は送らない
  def fill(values)
    body.split("\n", -1).filter_map do |line|
      next if values.any? { |placeholder, value| value.blank? && line.include?(placeholder) }

      values.reduce(line) { |text, (placeholder, value)| text.gsub(placeholder, value.to_s) }
    end.join("\n").strip
  end

  def validate_timings
    list = timing_list
    if list.any? { |timing| !DAYS_BEFORE.cover?(timing.days_before) || !HOURS.cover?(timing.hour) }
      errors.add(:timings, "の日数・時刻が正しくありません")
    end
    errors.add(:timings, "は1つにしてください") if preparation? && list.size != 1
    errors.add(:timings, "は設定できません（登録がそろったときに送ります）") if !scheduled? && list.any?
    errors.add(:timings, "に同じ日数のものが2つあります。日数を変えるか消してください") if list.map(&:days_before).uniq.size != list.size
  end
end
