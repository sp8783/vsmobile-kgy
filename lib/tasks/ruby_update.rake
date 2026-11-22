namespace :ruby_update do
  desc "Ruby の新版があるか確かめて表示する（書き換えない）"
  task check: :environment do
    current, plan = ruby_update_plan
    print_ruby_update_plan(current, plan)
  end

  desc "（GitHub Actions 用）Ruby の新版があれば、版と ruby/setup-ruby の固定を上げて PR を作る・更新する・閉じる"
  task publish: :environment do
    current, plan = ruby_update_plan
    print_ruby_update_plan(current, plan)
    unless plan.none?
      changed = RubyUpdate::Applier.new.apply(plan)
      puts "書き換え: #{changed.join(', ')}"
    end
    puts "Ruby 更新の PR: #{RubyUpdate::Publisher.new.publish(plan, current:)}"
  end

  def ruby_update_plan
    sources = RubyUpdate::Sources.new
    setup_ruby = sources.latest_setup_ruby
    current = Rails.root.join(RubyUpdate::Applier::VERSION_FILE).read.strip
    plan = RubyUpdate::Checker.new(current:, available: sources.available_versions(setup_ruby.tag), setup_ruby:,
                                   image_exists: sources.method(:image_exists?)).plan
    [ current, plan ]
  end

  def print_ruby_update_plan(current, plan)
    puts "今の Ruby: #{current} / ruby/setup-ruby の最新: #{plan.setup_ruby.tag}"
    puts plan.none? ? "新しい版はありません" : "上げる: #{plan.version}（#{plan.kind}）"
  end
end
