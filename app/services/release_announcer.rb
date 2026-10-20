# config/release_notes/v{x.y.z}.yml の告知文を、まだ告知していないバージョンについて
# アプリ内お知らせと Discord に出す。起動時に毎回実行する（告知済みのバージョンは何もしない）
#
# ファイルの形式:
#   title: アプリ内お知らせのタイトル
#   body: アプリ内お知らせの本文（Markdown）
#   discord: Discord に投稿する本文（省略すると Discord には投稿しない）
class ReleaseAnnouncer
  Note = Struct.new(:version, :title, :body, :discord, keyword_init: true)
  Result = Struct.new(:version, :announced, :discord_posted, keyword_init: true)

  DEFAULT_DIR = Rails.root.join("config/release_notes")
  DISCORD_LIMIT = 2000
  # Discord 投稿に失敗したときの再送は、告知を作ってからこの期間だけ行う（古いリリースを後から流さない）
  DISCORD_RETRY_WINDOW = 3.days

  def self.load_notes(dir = DEFAULT_DIR)
    Dir[File.join(dir, "v*.yml")]
      .map { |path| parse(path) }
      .sort_by { |note| Gem::Version.new(note.version.delete_prefix("v")) }
  end

  def self.parse(path)
    data = YAML.safe_load_file(path)
    Note.new(
      version: File.basename(path, ".yml"),
      title: data.fetch("title"),
      body: data.fetch("body"),
      discord: data["discord"].presence
    )
  end

  def initialize(dir: DEFAULT_DIR, poster: ->(message) { DiscordWebhookService.post(purpose: "release", message: message) })
    @dir = dir
    @poster = poster
  end

  def call
    self.class.load_notes(dir).map { |note| announce(note) }
  end

  private

  attr_reader :dir, :poster

  def announce(note)
    record = ReleaseAnnouncement.find_by(version: note.version)
    announced = record.nil?
    record ||= create_announcement(note)

    discord_posted = false
    if note.discord && record.discord_posted_at.nil? && record.created_at > DISCORD_RETRY_WINDOW.ago
      discord_posted = poster.call(note.discord)
      record.update!(discord_posted_at: Time.current) if discord_posted
    end

    Result.new(version: note.version, announced: announced, discord_posted: discord_posted)
  end

  def create_announcement(note)
    ReleaseAnnouncement.transaction do
      announcement = Announcement.create!(title: note.title, body: note.body, is_active: true, published_at: Time.current)
      ReleaseAnnouncement.create!(version: note.version, announcement: announcement)
    end
  end
end
