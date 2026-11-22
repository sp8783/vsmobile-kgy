module RubyUpdate
  # Ruby 更新の PR を作る・更新する・閉じる（GitHub Actions「Ruby の更新確認」から使う）
  #
  # - ブランチは chore/ruby-<版>。main から作り直して同じブランチを上書きし、中身が変わったときだけ push する
  # - 開いている Ruby 更新の PR は常に 1 つ。対象の版が変わったら古い PR を閉じる
  # - patch は自動マージを予約する（main のブランチ保護で CI が必須なので、通れば入る）。minor / major は下書き
  # - Issue は作らない（Dependabot の PR と同じ扱い）
  class Publisher
    LABEL = "技術基盤/機能".freeze
    PATHS = [ Applier::VERSION_FILE, Applier::DOCKERFILE, *Applier::DOCS, ".github/workflows" ].freeze

    PullRequest = Data.define(:number, :head, :draft, :url)

    def initialize(shell: CommandShell.new)
      @shell = shell
    end

    # 作業ツリーは main から作り直し、Applier で反映済みの状態で呼ぶ。:created / :updated / :unchanged / :closed を返す
    def publish(plan, current:)
      if plan.none?
        return :unchanged unless open_pr

        close(open_pr, "Ruby が最新の版になったため閉じます。")
        return :closed
      end

      branch = "chore/ruby-#{plan.version}"
      pr = open_pr
      if pr && pr.head != branch
        close(pr, "対象の版が #{plan.version} に変わったため閉じます。")
        pr = nil
      end

      commit(plan)
      return :unchanged if pr && same_as_remote?(branch)

      shell.run("git", "push", "--force", "origin", "HEAD:refs/heads/#{branch}")
      body = PullRequestBody.new(plan, current:).to_s
      if pr
        shell.run("gh", "pr", "edit", pr.number.to_s, "--body", body)
        :updated
      else
        url = shell.capture("gh", "pr", "create", "--base", "main", "--head", branch, "--title", title(plan), "--body", body, "--label", LABEL,
                            *("--draft" if plan.draft?)).strip
        shell.run("gh", "pr", "merge", "--auto", "--merge", url) unless plan.draft?
        :created
      end
    end

    private

    attr_reader :shell

    def open_pr
      return @open_pr if defined?(@open_pr)

      list = JSON.parse(shell.capture("gh", "pr", "list", "--state", "open", "--label", LABEL, "--limit", "50", "--json", "number,headRefName,isDraft,body,url"))
      found = list.find { |pr| pr["body"].to_s.include?(PullRequestBody::MARKER) }
      @open_pr = found && PullRequest.new(number: found["number"], head: found["headRefName"], draft: found["isDraft"], url: found["url"])
    end

    def title(plan)
      plan.draft? ? "chore: Ruby を #{plan.version} に更新（minor / major・要確認）" : "chore: Ruby を #{plan.version} に更新"
    end

    def commit(plan)
      shell.run("git", "add", "--all", "--", *PATHS)
      shell.run("git", "commit", "--quiet", "-m", "chore: upgrade ruby to #{plan.version}")
    end

    def same_as_remote?(branch)
      shell.run("git", "fetch", "--quiet", "origin", branch)
      shell.capture("git", "rev-parse", "FETCH_HEAD^{tree}") == shell.capture("git", "rev-parse", "HEAD^{tree}")
    end

    def close(pr, reason)
      shell.run("gh", "pr", "close", pr.number.to_s, "--delete-branch", "--comment", reason)
    end
  end
end
