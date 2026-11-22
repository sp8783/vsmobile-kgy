require "test_helper"

class RubyUpdate::ApplierTest < ActiveSupport::TestCase
  OLD_SHA = "b" * 40
  NEW_SHA = "c" * 40

  setup do
    @root = Pathname(Dir.mktmpdir)
    @root.join("docs").mkpath
    @root.join(".github/workflows").mkpath
    @root.join(".ruby-version").write("4.0.10\n")
    @root.join("Dockerfile").write("# syntax=docker/dockerfile:1\nARG RUBY_VERSION=4.0.10\nFROM docker.io/library/ruby:$RUBY_VERSION-slim AS base\n")
    @root.join("README.md").write("## 開発\n\nRuby 4.0.10 / Rails 8.1 / PostgreSQL\n")
    @root.join("docs/development.md").write("- Ruby 4.0.10（`.ruby-version`）\n- Docker\n")
    @root.join(".github/workflows/deploy.yml").write("      - uses: ruby/setup-ruby@#{OLD_SHA} # v1.334.0\n      - uses: actions/checkout@v7\n")
    @root.join(".github/workflows/ci.yml").write("      - uses: ruby/setup-ruby@v1\n")
  end

  teardown do
    FileUtils.remove_entry(@root)
  end

  test "版を持つファイルと、SHA 固定の ruby/setup-ruby を書き換え、変えたファイルだけ返す" do
    plan = RubyUpdate::Checker::Plan.new(kind: :patch, version: "4.0.11", setup_ruby: RubyUpdate::Checker::SetupRuby.new(tag: "v1.343.0", sha: NEW_SHA))

    changed = RubyUpdate::Applier.new(root: @root).apply(plan)

    assert_equal %w[.ruby-version Dockerfile README.md docs/development.md .github/workflows/deploy.yml], changed
    assert_equal "4.0.11\n", @root.join(".ruby-version").read
    assert_includes @root.join("Dockerfile").read, "ARG RUBY_VERSION=4.0.11\n"
    assert_includes @root.join("README.md").read, "Ruby 4.0.11 / Rails 8.1"
    assert_includes @root.join("docs/development.md").read, "- Ruby 4.0.11（"
    assert_includes @root.join(".github/workflows/deploy.yml").read, "ruby/setup-ruby@#{NEW_SHA} # v1.343.0"
    assert_includes @root.join(".github/workflows/deploy.yml").read, "actions/checkout@v7"
    assert_equal "      - uses: ruby/setup-ruby@v1\n", @root.join(".github/workflows/ci.yml").read
  end
end
