module MobileSuitUpdate
  # 機体データ更新の PR 本文（毎回作り直す）
  class PullRequestBody
    # 自動で作った PR の目印（開いている機体データ更新の PR を探すのに使う）
    MARKER = "<!-- mobile-suit-update -->".freeze

    def initialize(diff, kept:, base:, issue:, version: nil)
      @diff = diff
      @kept = kept
      @base = base
      @issue = issue
      @version = version
    end

    def to_s
      [
        MARKER,
        intro,
        incomplete_section,
        added_section,
        changed_section,
        removed_section,
        other_section,
        release_text_section,
        checklist_section,
        "Closes ##{issue}"
      ].compact.join("\n\n") + "\n"
    end

    private

    attr_reader :diff, :kept, :base, :issue, :version

    def standalone? = version.present?

    def intro
      lines = [ "毎日 5:00 の Wiki の取り直しで見つかった、機体データの変化です。" ]
      lines << if standalone?
        "単独リリース（#{version}）です。マージすると本番にデプロイされ、アプリ内お知らせと Discord に告知されます。"
      else
        "`#{base}` のリリースに含めます。"
      end
      lines << "このPRは自動で作り直します（手で編集した内容は、次に変化が見つかったときに上書きされます）。"
      lines.join("\n")
    end

    def incomplete_section
      return if diff.complete?

      lines = diff.incomplete.map { |item| "- `#{item.suit[:name]}`: #{item.missing.join('・')}" }
      [ "## ⚠ 情報不足（下書きにしています）", "Wiki にまだ載っていない情報があります。そろうと自動でレビュー可能になります。", *lines ].join("\n")
    end

    def added_section
      return if diff.added.empty?

      rows = diff.added.map do |suit|
        image = diff.incomplete.any? { |item| item.suit == suit && item.missing.include?("画像") } ? "⚠ なし" : "あり"
        row(suit[:name], suit[:cost], suit[:series], suit[:durability], suit[:bd_count], suit[:red_lock_range], image)
      end
      [ "## 新しい機体", row("機体", "コスト", "シリーズ", "耐久値", "BD回数", "赤ロック距離", "画像"), "|---|---|---|---|---|---|---|", *rows ].join("\n")
    end

    def changed_section
      return if diff.changed.empty?

      rows = diff.changed.flat_map do |change|
        change.fields.map { |key, (before, after)| row(change.after[:name], CatalogDiff::FIELDS[key], before, after) }
      end
      [ "## 変わった機体", row("機体", "項目", "変更前", "変更後"), "|---|---|---|---|", *rows ].join("\n")
    end

    def removed_section
      return if diff.removed.empty?

      [ "## Wiki から消えた機体", "アプリからは消しません（過去の試合で使われているため）。", *diff.removed.map { |suit| "- `#{suit[:name]}`" } ].join("\n")
    end

    def other_section
      lines = []
      lines << "- 並び順だけ変わった機体: #{diff.position_only_count}機" if diff.position_only_count.positive?
      lines << "- 値が取れず、今の値を残した機体: #{kept.join('、')}" if kept.any?
      [ "## そのほか", *lines ].join("\n") if lines.any?
    end

    def release_text_section
      if standalone?
        return "## 告知文\n`config/release_notes/#{version}.yml`（これまでの告知と同じ形で自動で作っています）"
      end

      text = ReleaseText.new(diff)
      [
        "## 告知文に足す節",
        "リリース PR の告知文（`config/release_notes/vX.Y.Z.yml`）に、次の節を足します。",
        "**アプリ内お知らせ**", fence(text.app_sections.join("\n\n")),
        "**Discord**", fence(text.discord_sections.join("\n\n"))
      ].join("\n\n")
    end

    def checklist_section
      return if diff.added.empty?

      "## 確認すること\n- [ ] 新しい機体がゲームで使えるか（まだ使えないときは、`config/mobile_suits.yml` の `exclude_page_ids` にページ ID を足す）"
    end

    def row(*cells)
      "| #{cells.map { |cell| cell.to_s.presence&.gsub('|', '\|') || '-' }.join(' | ')} |"
    end

    def fence(text)
      "````\n#{text}\n````"
    end
  end
end
