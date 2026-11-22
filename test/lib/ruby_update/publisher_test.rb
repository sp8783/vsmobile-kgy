require "test_helper"

class RubyUpdate::PublisherTest < ActiveSupport::TestCase
  SETUP_RUBY = RubyUpdate::Checker::SetupRuby.new(tag: "v1.343.0", sha: "a" * 40)
  PR_URL = "https://github.com/sp8783/vsmobile-kgy/pull/900".freeze

  # git・gh の代わり。決まった出力を返し、実行したコマンドを記録する
  class FakeShell
    attr_reader :commands

    def initialize(prs: [], remote_tree: "tree-old")
      @prs = prs
      @remote_tree = remote_tree
      @commands = []
    end

    def capture(*command)
      @commands << command
      case command.first(3)
      in [ "gh", "pr", "list" ] then @prs.to_json
      in [ "gh", "pr", "create" ] then "#{PR_URL}\n"
      in [ "git", "rev-parse", "FETCH_HEAD^{tree}" ] then @remote_tree
      in [ "git", "rev-parse", _ ] then "tree-new"
      end
    end

    def run(*command)
      @commands << command
    end

    def find(*prefix)
      @commands.find { |command| command.first(prefix.size) == prefix }
    end

    def ran?(*prefix) = !find(*prefix).nil?
  end

  test "patch なら PR を作り、自動マージを予約する" do
    shell = FakeShell.new

    result = publish(shell, kind: :patch, version: "4.0.11")

    assert_equal :created, result
    assert_equal [ "git", "push", "--force", "origin", "HEAD:refs/heads/chore/ruby-4.0.11" ], shell.find("git", "push")
    create = shell.find("gh", "pr", "create")
    assert_includes create, "chore: Ruby を 4.0.11 に更新"
    assert_includes create, "技術基盤/機能"
    assert_not_includes create, "--draft"
    assert_includes create[create.index("--body") + 1], "Ruby 4.0.10 → 4.0.11（patch）"
    assert_equal [ "gh", "pr", "merge", "--auto", "--merge", PR_URL ], shell.find("gh", "pr", "merge")
  end

  test "minor なら下書きの PR にして、自動マージは予約しない" do
    shell = FakeShell.new

    publish(shell, kind: :minor, version: "4.1.0")

    create = shell.find("gh", "pr", "create")
    assert_includes create, "--draft"
    assert_includes create, "chore: Ruby を 4.1.0 に更新（minor / major・要確認）"
    assert_not shell.ran?("gh", "pr", "merge")
  end

  test "同じ版の PR が開いていて中身も同じなら、何もしない" do
    shell = FakeShell.new(prs: [ pr(900, head: "chore/ruby-4.0.11") ], remote_tree: "tree-new")

    assert_equal :unchanged, publish(shell, kind: :patch, version: "4.0.11")
    assert_not shell.ran?("git", "push")
  end

  test "同じ版の PR が開いていて中身が変わっていれば、push して本文を更新する" do
    shell = FakeShell.new(prs: [ pr(900, head: "chore/ruby-4.0.11") ])

    assert_equal :updated, publish(shell, kind: :patch, version: "4.0.11")
    assert shell.ran?("git", "push")
    assert_equal "900", shell.find("gh", "pr", "edit")[3]
    assert_not shell.ran?("gh", "pr", "create")
  end

  test "対象の版が変わったら、古い PR を閉じて新しく作る" do
    shell = FakeShell.new(prs: [ pr(900, head: "chore/ruby-4.0.11") ])

    assert_equal :created, publish(shell, kind: :patch, version: "4.0.12")
    assert_equal "900", shell.find("gh", "pr", "close")[3]
    assert_includes shell.find("gh", "pr", "create"), "chore/ruby-4.0.12"
  end

  test "新しい版がなくなったら、開いている PR を閉じる" do
    shell = FakeShell.new(prs: [ pr(900, head: "chore/ruby-4.0.11") ])

    assert_equal :closed, publish(shell, kind: :none, version: "4.0.10")
    assert shell.ran?("gh", "pr", "close")
    assert_not shell.ran?("git", "commit")
  end

  test "新しい版がなく PR もなければ、何もしない" do
    shell = FakeShell.new

    assert_equal :unchanged, publish(shell, kind: :none, version: "4.0.10")
    assert_equal [ [ "gh", "pr", "list", "--state", "open", "--label", "技術基盤/機能", "--limit", "50", "--json", "number,headRefName,isDraft,body,url" ] ], shell.commands
  end

  private

  def publish(shell, kind:, version:)
    plan = RubyUpdate::Checker::Plan.new(kind:, version:, setup_ruby: SETUP_RUBY)
    RubyUpdate::Publisher.new(shell:).publish(plan, current: "4.0.10")
  end

  def pr(number, head:)
    { "number" => number, "headRefName" => head, "isDraft" => false, "body" => "#{RubyUpdate::PullRequestBody::MARKER}\n…", "url" => PR_URL }
  end
end
