module MobileSuitUpdate
  # 機体データ更新の PR を作る・更新する・閉じる（GitHub Actions「機体データの更新確認」から使う）
  #
  # - 開発中のリリースブランチ（最新のタグより新しい release/vX.Y.Z）があれば相乗り:
  #   feature/{Issue番号}-update-mobile-suits から、そのリリースブランチ向けの PR
  # - なければ、または単独で出すときは、main から次のパッチ版の release/vX.Y.Z を切り、main 向けのリリース PR（告知文つき）
  # - 開いている機体データ更新の PR は常に 1 つ。毎回起点から作り直して同じブランチを上書きし、中身が変わったときだけ push する
  class Publisher
    LABEL = "データ整備".freeze
    RELEASE_NOTES_DIR = "config/release_notes".freeze
    DATA_PATHS = [ Refresher::DATA_PATH, Refresher::IMAGE_DIR, RELEASE_NOTES_DIR ].freeze

    PullRequest = Data.define(:number, :head, :base, :draft, :issue)
    # pr: 今の向き先にそのまま使える、開いている機体データ更新の PR
    Target = Data.define(:base, :version, :pr) do
      def standalone? = !version.nil?
    end

    def initialize(standalone: false, shell: CommandShell.new, root: Rails.root)
      @standalone = standalone
      @shell = shell
      @root = Pathname(root)
    end

    # 取り直しの起点にするブランチを決める（取り直しの前に呼ぶ）
    def target
      @target ||= begin
        development = development_branch
        if @standalone || development.nil?
          version = "v#{next_patch}"
          Target.new(base: "main", version:, pr: reusable(base: "main", head: "release/#{version}"))
        else
          Target.new(base: development, version: nil, pr: reusable(base: development))
        end
      end
    end

    # 作業ツリーは target.base から作り直し、Refresher で反映済みの状態で呼ぶ。:created / :updated / :unchanged / :closed を返す
    def publish(result)
      if open_pr && open_pr != target.pr
        close(open_pr, target.standalone? ? "単独リリース（#{target.version}）に切り替えるため閉じます。" : "`#{target.base}` への相乗りに切り替えるため閉じます。")
      end

      diff = result.diff
      unless diff.changes?
        return :unchanged unless target.pr

        close(target.pr, "Wiki の機体データがアプリと同じになったため閉じます。")
        shell.run("gh", "issue", "close", target.pr.issue.to_s, "--reason", "not planned", "--comment", "Wiki の機体データがアプリと同じになったため閉じます。") if target.pr.issue
        return :closed
      end

      write_release_note(diff) if target.standalone?
      # 向き先を切り替えて閉じた PR の Issue は、そのまま使い続ける
      issue = target.pr&.issue || open_pr&.issue || create_issue
      branch = target.pr&.head || (target.standalone? ? "release/#{target.version}" : "feature/#{issue}-update-mobile-suits")
      commit
      return :unchanged if target.pr && same_as_remote?(branch)

      shell.run("git", "push", "--force", "origin", "HEAD:refs/heads/#{branch}")
      body = PullRequestBody.new(diff, kept: result.kept, base: target.base, issue:, version: target.version).to_s
      if target.pr
        shell.run("gh", "pr", "edit", target.pr.number.to_s, "--body", body)
        draft(target.pr, !diff.complete?)
        :updated
      else
        shell.run("gh", "pr", "create", "--base", target.base, "--head", branch, "--title", pr_title, "--body", body, "--label", LABEL, *("--draft" unless diff.complete?))
        :created
      end
    end

    private

    attr_reader :shell, :root

    def open_pr
      return @open_pr if defined?(@open_pr)

      list = JSON.parse(shell.capture("gh", "pr", "list", "--state", "open", "--label", LABEL, "--limit", "50",
                                      "--json", "number,headRefName,baseRefName,isDraft,body"))
      found = list.find { |pr| pr["body"].to_s.include?(PullRequestBody::MARKER) }
      @open_pr = found && PullRequest.new(number: found["number"], head: found["headRefName"], base: found["baseRefName"],
                                          draft: found["isDraft"], issue: found["body"][/Closes #(\d+)/, 1]&.to_i)
    end

    def reusable(base:, head: nil)
      open_pr if open_pr && open_pr.base == base && (head.nil? || open_pr.head == head)
    end

    def latest_version
      @latest_version ||= shell.capture("git", "tag", "--list", "v*").split.filter_map { |tag| parse_version(tag) }.max
    end

    def next_patch
      major, minor, patch = latest_version.segments
      "#{major}.#{minor}.#{patch + 1}"
    end

    # 最新のタグより新しいリリースブランチのうち、いちばん近いもの（単独リリースで自分が作ったブランチは除く）
    def development_branch
      own = open_pr&.base == "main" ? open_pr.head : nil
      shell.capture("git", "ls-remote", "--heads", "origin", "release/v*").lines
        .map { |line| line.split.last.delete_prefix("refs/heads/") }
        .reject { |branch| branch == own }
        .filter_map { |branch| (version = parse_version(branch.delete_prefix("release/"))) && version > latest_version && [ version, branch ] }
        .min_by(&:first)&.last
    end

    def parse_version(name)
      Gem::Version.new(name.delete_prefix("v")) if name.match?(/\Av\d+\.\d+\.\d+\z/)
    end

    def pr_title
      target.standalone? ? "chore: #{target.version} リリース" : "chore: 機体データを Wiki の最新の情報に更新"
    end

    def write_release_note(diff)
      root.join(RELEASE_NOTES_DIR, "#{target.version}.yml").write(ReleaseText.new(diff, version: target.version).to_release_note.to_yaml)
    end

    def create_issue
      url = shell.capture("gh", "issue", "create", "--title", "機体データを Wiki の最新の情報に更新する", "--label", LABEL, "--body", <<~BODY)
        ## 概要
        Wiki（毎日 5:00 の取り直し）で見つかった機体データの変化を、アプリに反映する。

        ## 背景
        機体データの更新確認（GitHub Actions）が、アプリが使う項目（機体名・コスト・シリーズ・耐久値・BD回数・赤ロック距離・画像）の変化を見つけた。

        ## 対応内容
        - `db/data/units.json` と機体画像を更新する（内容は PR を参照）

        ## 備考
        この Issue は自動で作成しています。
      BODY
      url[%r{/issues/(\d+)}, 1].to_i
    end

    def commit
      shell.run("git", "add", "--all", "--", *DATA_PATHS)
      shell.run("git", "commit", "--quiet", "-m", "chore: update mobile suit data from wiki")
    end

    def same_as_remote?(branch)
      shell.run("git", "fetch", "--quiet", "origin", branch)
      shell.capture("git", "rev-parse", "FETCH_HEAD^{tree}") == shell.capture("git", "rev-parse", "HEAD^{tree}")
    end

    def draft(pr, value)
      return if pr.draft == value

      shell.run("gh", "pr", "ready", pr.number.to_s, *("--undo" if value))
    end

    def close(pr, reason)
      shell.run("gh", "pr", "close", pr.number.to_s, "--delete-branch", "--comment", reason)
    end
  end
end
