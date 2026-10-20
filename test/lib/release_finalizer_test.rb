require "test_helper"

class ReleaseFinalizerTest < ActiveSupport::TestCase
  RELEASE_BODY = <<~BODY.freeze
    ## Summary
    release/v2.4.0 を main にマージするリリースPRです。

    ## 主な変更
    - 対戦結果入力の機体プルダウンの先頭に、最近使った機体を出す (#381)
    - Discord の投稿文を管理画面で設定できるようにする (#379)
    - お気に入り機体: 上限 18 機 (#350)、選択中の絞り込み (#357)

    ## 関連Issue・PR
    - #381（#380）

    Closes #390
  BODY

  # git・gh の代わり。決まった出力を返し、実行したコマンドを記録する
  class FakeShell
    attr_reader :commands

    def initialize(pulls:, tags: "", release_exists: false, issue_states: {}, project_items: [], project_error: false)
      @pulls = pulls
      @tags = tags
      @release_exists = release_exists
      @issue_states = issue_states
      @project_items = project_items
      @project_error = project_error
      @commands = []
    end

    def capture(*command, env: {})
      @commands << [ command, env ]
      case command
      in [ "gh", "api", %r{/commits/} ] then @pulls.to_json
      in [ "git", "tag", "--list", _ ] then @tags
      in [ "gh", "release", "view", * ] then @release_exists ? "v2.4.0" : raise("not found")
      in [ "gh", "pr", "list", * ] then [ { "body" => "Closes #380" }, { "body" => "fixes #378\nCloses #380" }, { "body" => "依存の更新" } ].to_json
      in [ "gh", "issue", "view", number, * ] then @issue_states.fetch(number.to_i, "OPEN")
      in [ "gh", "project", "item-list", * ]
        raise "権限がありません" if @project_error

        { "items" => @project_items }.to_json
      end
    end

    def run(*command, env: {})
      @commands << [ command, env ]
    end

    def find(*prefix)
      @commands.map(&:first).find { |command| command.first(prefix.size) == prefix }
    end

    def ran?(*prefix) = !find(*prefix).nil?
  end

  test "リリース PR のマージなら、主な変更からタグと GitHub Release を作る（タグには PR 番号を付けない）" do
    shell = FakeShell.new(pulls: [ release_pr ])

    result = finalizer(shell).call

    assert_equal [ "v2.4.0", true, true ], [ result.version, result.tagged, result.released ]
    tag = shell.find("git", "tag", "-a")
    assert_equal [ "v2.4.0", "abc123" ], tag[3, 2]
    assert_equal <<~MESSAGE, tag.last
      VS.Mobile for KGY v2.4.0

      主な変更:
      - 対戦結果入力の機体プルダウンの先頭に、最近使った機体を出す
      - Discord の投稿文を管理画面で設定できるようにする
      - お気に入り機体: 上限 18 機、選択中の絞り込み
    MESSAGE
    assert shell.ran?("git", "push", "origin", "v2.4.0")
    release = shell.find("gh", "release", "create", "v2.4.0")
    assert_includes release, "--latest"
    assert_equal "## 主な変更\n- 対戦結果入力の機体プルダウンの先頭に、最近使った機体を出す (#381)\n- Discord の投稿文を管理画面で設定できるようにする (#379)\n- お気に入り機体: 上限 18 機 (#350)、選択中の絞り込み (#357)\n",
                 release[release.index("--notes") + 1]
  end

  test "リリースブランチにマージした PR とリリース PR の Issue を閉じ、閉じている Issue はそのまま" do
    shell = FakeShell.new(pulls: [ release_pr ], issue_states: { 378 => "CLOSED" })

    result = finalizer(shell).call

    assert_equal [ 380, 390 ], result.closed_issues
    assert_includes shell.find("gh", "issue", "close", "380"), "v2.4.0 でリリースしました。"
    assert_not shell.ran?("gh", "issue", "close", "378")
  end

  test "Project のトークンがあれば、Issue を Done にする（Done 済み・ほかのリポジトリの Issue は除く）" do
    items = [
      { "id" => "ITEM380", "status" => "In review", "content" => { "number" => 380, "repository" => "sp8783/vsmobile-kgy" } },
      { "id" => "ITEM378", "status" => "Done", "content" => { "number" => 378, "repository" => "sp8783/vsmobile-kgy" } },
      { "id" => "OTHER390", "status" => "In review", "content" => { "number" => 390, "repository" => "sp8783/other" } }
    ]
    shell = FakeShell.new(pulls: [ release_pr ], project_items: items)

    result = finalizer(shell, project_token: "token").call

    assert_equal [ 380 ], result.done_issues
    edit = shell.commands.find { |command, _| command.first(3) == %w[gh project item-edit] }
    assert_includes edit.first, "ITEM380"
    assert_equal({ "GH_TOKEN" => "token" }, edit.last)
  end

  test "Project を更新できなくても、ほかの作業は済ませて止まらない" do
    logs = []
    shell = FakeShell.new(pulls: [ release_pr ], project_error: true)

    result = finalizer(shell, project_token: "token", log: ->(message) { logs << message }).call

    assert_equal [ [], true ], [ result.done_issues, result.tagged ]
    assert_match "GitHub Project を更新できませんでした", logs.last
  end

  test "タグと GitHub Release がすでにあれば作り直さない" do
    shell = FakeShell.new(pulls: [ release_pr ], tags: "v2.4.0\n", release_exists: true)

    result = finalizer(shell).call

    assert_equal [ false, false ], [ result.tagged, result.released ]
    assert_not shell.ran?("git", "tag", "-a")
    assert_not shell.ran?("gh", "release", "create")
  end

  test "リリース PR 以外（hotfix など）のマージでは何もしない" do
    shell = FakeShell.new(pulls: [ release_pr.merge("head" => { "ref" => "hotfix/368-close-db-port" }) ])

    assert_nil finalizer(shell, log: ->(_) { }).call
    assert_not shell.ran?("git", "tag", "-a")
  end

  test "主な変更がなければ、PR のタイトルを使う" do
    shell = FakeShell.new(pulls: [ release_pr.merge("body" => "Closes #390") ])

    finalizer(shell).call

    assert_match "主な変更:\n- chore: v2.4.0 リリース\n", shell.find("git", "tag", "-a").last
  end

  private

  def finalizer(shell, project_token: nil, log: ->(_) { })
    ReleaseFinalizer.new(sha: "abc123", repo: "sp8783/vsmobile-kgy", shell:, project_token:, log:)
  end

  def release_pr
    { "number" => 391, "title" => "chore: v2.4.0 リリース", "merged_at" => "2026-10-12T00:00:00Z", "body" => RELEASE_BODY,
      "base" => { "ref" => "main" }, "head" => { "ref" => "release/v2.4.0" } }
  end
end
