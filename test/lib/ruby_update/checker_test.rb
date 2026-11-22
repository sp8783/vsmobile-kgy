require "test_helper"

class RubyUpdate::CheckerTest < ActiveSupport::TestCase
  SETUP_RUBY = RubyUpdate::Checker::SetupRuby.new(tag: "v1.343.0", sha: "a" * 40)

  test "同じ minor の新しい patch があれば patch で上げる（minor の候補があっても patch を先に）" do
    plan = plan(current: "4.0.10", available: %w[4.0.9 4.0.10 4.0.11 4.0.12 4.1.0])

    assert_equal [ :patch, "4.0.12" ], [ plan.kind, plan.version ]
    assert_not plan.draft?
  end

  test "Docker Hub にイメージがない版は飛ばす" do
    plan = plan(current: "4.0.10", available: %w[4.0.11 4.0.12], images: %w[4.0.11])

    assert_equal "4.0.11", plan.version
  end

  test "patch がなく、新しい minor があれば minor で上げる（下書き）" do
    plan = plan(current: "4.0.10", available: %w[4.0.10 4.1.0 4.1.1])

    assert_equal [ :minor, "4.1.1" ], [ plan.kind, plan.version ]
    assert plan.draft?
  end

  test "preview / rc と今より古い版は候補にしない" do
    plan = plan(current: "4.0.10", available: %w[3.4.13 4.0.9 4.0.10 4.1.0-preview1 4.1.0-rc1])

    assert plan.none?
    assert_equal "4.0.10", plan.version
    assert_equal SETUP_RUBY, plan.setup_ruby
  end

  private

  def plan(current:, available:, images: nil)
    RubyUpdate::Checker.new(current:, available:, setup_ruby: SETUP_RUBY,
                            image_exists: ->(version) { images.nil? || images.include?(version) }).plan
  end
end
