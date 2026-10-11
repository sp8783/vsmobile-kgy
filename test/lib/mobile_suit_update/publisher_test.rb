require "test_helper"

class MobileSuitUpdate::PublisherTest < ActiveSupport::TestCase
  include MobileSuitUnitHelper

  # git・gh の代わり。決まった出力を返し、実行したコマンドを記録する
  class FakeShell
    attr_reader :commands

    def initialize(tags: %w[v2.3.0 v2.3.1], release_branches: [], prs: [], remote_tree: "tree-old")
      @tags = tags
      @release_branches = release_branches
      @prs = prs
      @remote_tree = remote_tree
      @commands = []
    end

    def capture(*command)
      @commands << command
      case command.first(3)
      in [ "git", "tag", _ ] then @tags.join("\n")
      in [ "git", "ls-remote", _ ] then @release_branches.map { |branch| "abc123\trefs/heads/#{branch}\n" }.join
      in [ "gh", "pr", "list" ] then @prs.to_json
      in [ "gh", "issue", "create" ] then "https://github.com/sp8783/vsmobile-kgy/issues/500\n"
      in [ "git", "rev-parse", "FETCH_HEAD^{tree}" ] then @remote_tree
      in [ "git", "rev-parse", _ ] then "tree-new"
      end
    end

    def run(*command)
      @commands << command
    end

    def ran?(*prefix)
      @commands.any? { |command| command.first(prefix.size) == prefix }
    end

    def find(*prefix)
      @commands.find { |command| command.first(prefix.size) == prefix }
    end
  end

  setup do
    @root = Pathname(Dir.mktmpdir)
    @root.join("config/release_notes").mkpath
  end

  teardown do
    FileUtils.remove_entry(@root)
  end

  test "開発中のリリースブランチがあれば、そのブランチを起点に相乗りする" do
    shell = FakeShell.new(release_branches: %w[release/v2.3.1 release/v2.4.0 release/v2.5.0])

    target = publisher(shell).target

    assert_equal [ "release/v2.4.0", nil ], [ target.base, target.version ]
  end

  test "開発中のリリースブランチがなければ、main から次のパッチ版で単独リリースにする" do
    target = publisher(FakeShell.new(release_branches: %w[release/v2.3.1])).target

    assert_equal [ "main", "v2.3.2" ], [ target.base, target.version ]
  end

  test "単独で出すときは、開発中のリリースブランチがあっても単独リリースにする" do
    target = publisher(FakeShell.new(release_branches: %w[release/v2.4.0]), standalone: true).target

    assert_equal [ "main", "v2.3.2" ], [ target.base, target.version ]
  end

  test "自分で作った単独リリースのブランチは、開発中のリリースブランチとみなさない" do
    shell = FakeShell.new(release_branches: %w[release/v2.3.2], prs: [ pr(10, head: "release/v2.3.2", base: "main") ])

    target = publisher(shell).target

    assert_equal [ "main", "v2.3.2", 10 ], [ target.base, target.version, target.pr.number ]
  end

  test "相乗りの PR がなければ、Issue と feature ブランチを作り、リリースブランチ向けの PR を作る" do
    shell = FakeShell.new(release_branches: %w[release/v2.4.0])

    assert_equal :created, publisher(shell).publish(result(changed: true))

    assert shell.ran?("git", "push", "--force", "origin", "HEAD:refs/heads/feature/500-update-mobile-suits")
    create = shell.find("gh", "pr", "create")
    assert_equal "release/v2.4.0", create[create.index("--base") + 1]
    assert_equal "chore: 機体データを Wiki の最新の情報に更新", create[create.index("--title") + 1]
    assert_includes create[create.index("--body") + 1], "Closes #500"
    assert_not_includes create, "--draft"
  end

  test "単独リリースでは、告知文を作り、リリース PR を main 向けに作る" do
    shell = FakeShell.new

    publisher(shell).publish(result(changed: true))

    assert shell.ran?("git", "push", "--force", "origin", "HEAD:refs/heads/release/v2.3.2")
    create = shell.find("gh", "pr", "create")
    assert_equal [ "main", "chore: v2.3.2 リリース" ], [ create[create.index("--base") + 1], create[create.index("--title") + 1] ]
    assert_equal "🔧 v2.3.2 リリース！ 機体データを更新", YAML.safe_load_file(@root.join("config/release_notes/v2.3.2.yml"))["title"]
  end

  test "情報が足りない機体があれば、下書きの PR にする" do
    shell = FakeShell.new(release_branches: %w[release/v2.4.0])

    publisher(shell).publish(result(added_without_image: true))

    assert_includes shell.find("gh", "pr", "create"), "--draft"
  end

  test "開いている PR があれば、同じブランチを上書きして本文を更新し、情報がそろったら下書きを外す" do
    shell = FakeShell.new(release_branches: %w[release/v2.4.0],
                          prs: [ pr(20, head: "feature/400-update-mobile-suits", base: "release/v2.4.0", draft: true, issue: 400) ])

    assert_equal :updated, publisher(shell).publish(result(changed: true))

    assert shell.ran?("git", "push", "--force", "origin", "HEAD:refs/heads/feature/400-update-mobile-suits")
    assert shell.ran?("gh", "pr", "edit", "20")
    assert shell.ran?("gh", "pr", "ready", "20")
    assert_not shell.ran?("gh", "issue", "create")
  end

  test "開いている PR と中身が同じなら push しない" do
    shell = FakeShell.new(release_branches: %w[release/v2.4.0], remote_tree: "tree-new",
                          prs: [ pr(20, head: "feature/400-update-mobile-suits", base: "release/v2.4.0", issue: 400) ])

    assert_equal :unchanged, publisher(shell).publish(result(changed: true))

    assert_not shell.ran?("git", "push")
  end

  test "Wiki がアプリと同じになったら、開いている PR と Issue を閉じる" do
    shell = FakeShell.new(release_branches: %w[release/v2.4.0],
                          prs: [ pr(20, head: "feature/400-update-mobile-suits", base: "release/v2.4.0", issue: 400) ])

    assert_equal :closed, publisher(shell).publish(result(changed: false))

    assert shell.ran?("gh", "pr", "close", "20", "--delete-branch")
    assert shell.ran?("gh", "issue", "close", "400")
  end

  test "単独で出すときは、相乗りの PR を閉じ、同じ Issue で単独リリースの PR を作る" do
    shell = FakeShell.new(release_branches: %w[release/v2.4.0],
                          prs: [ pr(20, head: "feature/400-update-mobile-suits", base: "release/v2.4.0", issue: 400) ])

    publisher(shell, standalone: true).publish(result(changed: true))

    close = shell.find("gh", "pr", "close", "20")
    assert_includes close.last, "単独リリース（v2.3.2）に切り替える"
    create = shell.find("gh", "pr", "create")
    assert_equal "main", create[create.index("--base") + 1]
    assert_includes create[create.index("--body") + 1], "Closes #400"
  end

  private

  def publisher(shell, standalone: false)
    MobileSuitUpdate::Publisher.new(standalone:, shell:, root: @root)
  end

  def pr(number, head:, base:, draft: false, issue: 400)
    { "number" => number, "headRefName" => head, "baseRefName" => base, "isDraft" => draft,
      "body" => "#{MobileSuitUpdate::PullRequestBody::MARKER}\n\nCloses ##{issue}\n" }
  end

  def result(changed: false, added_without_image: false)
    before = [ suit_unit(1, "機体A", durability: "650") ]
    after = [ suit_unit(1, "機体A", durability: changed ? "600" : "650") ]
    after << suit_unit(2, "機体B", image: false) if added_without_image
    MobileSuitUpdate::Refresher::Result.new(diff: MobileSuitUpdate::CatalogDiff.new(before, after, image_dir: @root), kept: [])
  end
end
