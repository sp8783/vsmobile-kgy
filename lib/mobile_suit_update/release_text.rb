module MobileSuitUpdate
  # 機体データの更新の告知文。これまでのリリース告知（Vault の Changelog の「Discord告知文」「アプリ内お知らせ」）と同じ形にする
  #
  # - 単独リリースのとき: to_release_note を config/release_notes/v{x.y.z}.yml にする
  # - 相乗りのとき: app_sections / discord_sections を PR 本文に載せ、リリース PR の告知文に Claude が足す
  class ReleaseText
    APP_URL = "https://vsm-kgy.com/".freeze
    DIVIDER = "──────────────────────────────".freeze
    # Discord の #バグ報告・要望 へのリンク（Webhook の投稿では「#チャンネル名」はリンクにならないため <#ID> で書く）
    BUG_REPORT_CHANNEL = "<#1462281876524896458>".freeze
    DISCORD_LIMIT = ReleaseAnnouncer::DISCORD_LIMIT

    def initialize(diff, version: nil)
      @diff = diff
      @version = version
    end

    def to_release_note
      { "title" => title, "body" => body, "discord" => discord }
    end

    def title
      emoji = added.any? ? "🆕" : "🔧"
      "#{emoji} #{version} リリース！ #{[ ("新機体#{added.size}機#{changed.any? ? 'の追加' : 'を追加'}" if added.any?), ("機体データを更新" if changed.any?) ].compact.join('・')}"
    end

    def body
      [ "#{summary}。", *app_sections ].join("\n\n") + "\n"
    end

    def discord
      fit_discord(changed_lines(prefix: "  * "))
    end

    def app_sections
      sections = []
      sections << ([ "## 🆕 新機体" ] + added_lines(prefix: "- ")).join("\n") if added.any?
      sections << ([ "## 🔧 機体データの更新" ] + changed_lines(prefix: "- ")).join("\n") if changed.any?
      sections
    end

    def discord_sections(lines = changed_lines(prefix: "  * "))
      sections = []
      if added.any?
        names = added.map { |suit| "**#{suit[:name]}**" }
        sections << [ "## :new: **新機体**", "* #{names.size == 2 ? names.join(' と ') : names.join('、')} を追加しました :crossed_swords:", *added_lines(prefix: "  * ") ].join("\n")
      end
      if changed.any?
        sections << [ "## :wrench: **機体データの更新**", "* Wiki の最新の情報に合わせて、機体データを更新しました :crossed_swords:", *lines ].join("\n")
      end
      sections
    end

    # 調整した機体の 1 行。名前が変わった機体は「`旧名` → `新名`」
    def self.change_line(change)
      fields = change.fields.except(:name)
      name = change.fields.key?(:name) ? "`#{change.before[:name]}` → `#{change.after[:name]}`" : "`#{change.after[:name]}`"
      return name if fields.empty?

      details = fields.map { |key, (before, after)| "#{CatalogDiff::FIELDS[key]} #{before.presence || 'なし'} → #{after.presence || 'なし'}" }
      "#{name}（#{details.join('、')}）"
    end

    def self.added_line(suit)
      "`#{suit[:name]}`（コスト#{suit[:cost]} / #{suit[:series]}）"
    end

    private

    attr_reader :diff

    def version
      @version or raise ArgumentError, "単独リリースの告知文にはバージョンが必要です"
    end

    def added = diff.added
    def changed = diff.changed

    def summary
      kinds = [ ("新機体#{added.size}機の追加" if added.any?), ("機体データの更新" if changed.any?) ].compact
      "今回は#{kinds.join('と、')}アップデートです"
    end

    def added_lines(prefix:) = added.map { |suit| "#{prefix}#{self.class.added_line(suit)}" }
    def changed_lines(prefix:) = changed.map { |change| "#{prefix}#{self.class.change_line(change)}" }

    def discord_text(lines)
      [
        "@everyone",
        "# :sparkles: **VS.モバイル for KGY #{version} リリース！**",
        "#{version}をリリースしました :tada:\n#{summary}！",
        ":link: **アプリURL**\n#{APP_URL}",
        DIVIDER,
        *discord_sections(lines),
        DIVIDER,
        "**バグの報告**や**機能要望**は引き続き #{BUG_REPORT_CHANNEL} へお願いします :person_bowing:"
      ].join("\n\n") + "\n"
    end

    # Discord の文字数の上限を超えるときは、調整した機体の行を減らして「ほか N 機」にまとめる
    def fit_discord(lines)
      text = discord_text(lines)
      return text if text.length <= DISCORD_LIMIT

      kept = lines.dup
      loop do
        kept.pop
        text = discord_text(kept + [ "  * ほか#{lines.size - kept.size}機" ])
        return text if text.length <= DISCORD_LIMIT || kept.empty?
      end
    end
  end
end
