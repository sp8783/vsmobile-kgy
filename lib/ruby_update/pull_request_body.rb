module RubyUpdate
  # Ruby 更新の PR 本文（毎回作り直す）
  class PullRequestBody
    # 自動で作った PR の目印（開いている Ruby 更新の PR を探すのに使う）
    MARKER = "<!-- ruby-update -->".freeze
    NEWS_URL = "https://www.ruby-lang.org/en/news/".freeze

    def initialize(plan, current:)
      @plan = plan
      @current = current
    end

    def to_s
      [ MARKER, intro, changes_section, merge_section, "## 確認\n- Ruby の release notes: #{NEWS_URL}" ].join("\n\n") + "\n"
    end

    private

    attr_reader :plan, :current

    def intro
      "毎日 6:00 の Ruby の更新確認で見つかった、Ruby の新しい版です。\n" \
        "このPRは自動で作り直します（手で編集した内容は、次の実行で上書きされます）。"
    end

    def changes_section
      [
        "## 主な変更",
        "- Ruby #{current} → #{plan.version}（#{plan.kind}）。`.ruby-version`・Dockerfile・README・docs",
        "- `ruby/setup-ruby` の固定を #{plan.setup_ruby.tag}（`#{plan.setup_ruby.sha}`）に。Deploy と機体データの更新確認が新しい Ruby を知るため"
      ].join("\n")
    end

    def merge_section
      if plan.draft?
        "minor / major の更新なので下書きです。Claude が取り込んで直し、CI を通してレビュー可にします。マージは手で行ってください。"
      else
        "patch の更新です。CI が通れば自動でマージされ、本番にデプロイされます。"
      end
    end
  end
end
