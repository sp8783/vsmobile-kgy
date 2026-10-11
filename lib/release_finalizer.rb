# リリース PR（release/vX.Y.Z → main）のデプロイが成功したあとの作業を行う（.github/workflows/deploy.yml から使う）
#
# - annotated tag と GitHub Release（Latest）を作る。中身はリリース PR 本文の「## 主な変更」
#   （タグのメッセージには PR 番号を付けず、GitHub Release には付けたまま載せる。これまでのリリースと同じ形）
# - そのリリースに含まれる Issue（リリースブランチにマージした PR の「Closes #N」）を閉じ、GitHub Project を Done にする
#
# リリース PR のマージ以外（hotfix など）のデプロイでは何もしない。何度実行しても、済んだ作業はやり直さない
class ReleaseFinalizer
  APP_NAME = "VS.Mobile for KGY".freeze
  # GitHub Project「VS.モバイル for KGY 開発ボード」の Status を Done にするための ID（Vault の GitHub-Project.md）
  PROJECT = { owner: "sp8783", number: "1", id: "PVT_kwHOAmxFgc4BNPGz",
              status_field: "PVTSSF_lAHOAmxFgc4BNPGzzg8Skps", done: "98236657" }.freeze

  Result = Data.define(:version, :tagged, :released, :closed_issues, :done_issues)

  # project_token: GitHub Project を更新できるトークン（なければ Project は更新しない）
  def initialize(sha:, repo:, shell: CommandShell.new, project_token: nil, log: ->(message) { puts message })
    @sha = sha
    @repo = repo
    @shell = shell
    @project_token = project_token.presence
    @log = log
  end

  def call
    pr = release_pr
    unless pr
      log.call("リリース PR のマージではないため、何もしません（#{sha}）")
      return
    end

    version = pr["head"]["ref"].delete_prefix("release/")
    changes = changes_from(pr)
    tagged = tag(version, changes)
    released = release(version, changes)
    issues = issues_in(pr)
    closed = issues.select { |number| close_issue(number, version) }
    done = mark_all_done(issues)

    Result.new(version:, tagged:, released:, closed_issues: closed, done_issues: done)
  end

  private

  attr_reader :sha, :repo, :shell, :project_token, :log

  def release_pr
    pulls = JSON.parse(shell.capture("gh", "api", "repos/#{repo}/commits/#{sha}/pulls"))
    pulls.find { |pr| pr["merged_at"] && pr["base"]["ref"] == "main" && pr["head"]["ref"].match?(/\Arelease\/v\d+\.\d+\.\d+\z/) }
  end

  # リリース PR 本文の「## 主な変更」の箇条書き。なければ PR のタイトルを使う
  def changes_from(pr)
    section = pr["body"].to_s[/^## 主な変更\s*\n(.*?)(?=^## |\z)/m, 1].to_s
    lines = section.lines.map(&:rstrip).select { |line| line.start_with?("- ") }
    lines.presence || [ "- #{pr['title']}" ]
  end

  def tag(version, changes)
    return false if shell.capture("git", "tag", "--list", version).strip.present?

    message = "#{APP_NAME} #{version}\n\n主な変更:\n#{changes.map { |line| line.gsub(/\s*\(#\d+(?:[、,]\s*#\d+)*\)/, "") }.join("\n")}\n"
    shell.run("git", "tag", "-a", version, sha, "-m", message)
    shell.run("git", "push", "origin", version)
    true
  end

  def release(version, changes)
    return false if system_quiet("gh", "release", "view", version, "--repo", repo)

    shell.run("gh", "release", "create", version, "--repo", repo, "--title", version, "--latest", "--verify-tag",
              "--notes", "## 主な変更\n#{changes.join("\n")}\n")
    true
  end

  # リリースブランチにマージした PR と、リリース PR 自身の「Closes #N」
  def issues_in(pr)
    pulls = JSON.parse(shell.capture("gh", "pr", "list", "--repo", repo, "--state", "merged", "--base", pr["head"]["ref"],
                                     "--limit", "200", "--json", "body"))
    [ pr["body"], *pulls.map { |pull| pull["body"] } ].flat_map { |body| body.to_s.scan(/(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?) #(\d+)/i).flatten }
      .map(&:to_i).uniq.sort
  end

  def close_issue(number, version)
    state = shell.capture("gh", "issue", "view", number.to_s, "--repo", repo, "--json", "state", "--jq", ".state").strip
    return false unless state == "OPEN"

    shell.run("gh", "issue", "close", number.to_s, "--repo", repo, "--comment", "#{version} でリリースしました。")
    true
  end

  # Project の更新に失敗しても、ほかの作業（タグ・GitHub Release・Issue）は済んでいるので止めない
  def mark_all_done(issues)
    unless project_token
      log.call("GitHub Project を更新できるトークンがないため、Project は更新しません")
      return []
    end

    issues.select { |number| mark_done(number) }
  rescue RuntimeError => e
    log.call("GitHub Project を更新できませんでした: #{e.message}")
    []
  end

  def mark_done(number)
    env = { "GH_TOKEN" => project_token }
    @items ||= JSON.parse(shell.capture("gh", "project", "item-list", PROJECT[:number], "--owner", PROJECT[:owner],
                                        "--format", "json", "--limit", "500", env:))["items"]
    item = @items.find { |candidate| candidate.dig("content", "number") == number && candidate.dig("content", "repository").to_s.end_with?(repo) }
    return false unless item && item["status"] != "Done"

    shell.run("gh", "project", "item-edit", "--project-id", PROJECT[:id], "--id", item["id"],
              "--field-id", PROJECT[:status_field], "--single-select-option-id", PROJECT[:done], env:)
    true
  end

  def system_quiet(*command)
    shell.capture(*command)
    true
  rescue RuntimeError
    false
  end
end
