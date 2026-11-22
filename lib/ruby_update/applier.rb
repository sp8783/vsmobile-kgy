module RubyUpdate
  # Ruby の版を持っているファイルと、workflow で SHA 固定している ruby/setup-ruby を書き換える
  class Applier
    VERSION_FILE = ".ruby-version".freeze
    DOCKERFILE = "Dockerfile".freeze
    # 「Ruby x.y.z」と書いている文書
    DOCS = %w[README.md docs/development.md].freeze
    WORKFLOWS = ".github/workflows/*.yml".freeze

    SETUP_RUBY_PIN = %r{ruby/setup-ruby@[0-9a-f]{40} # v[\d.]+}

    def initialize(root: Rails.root)
      @root = Pathname(root)
    end

    # 書き換えたファイルのパス（root からの相対）を返す
    def apply(plan)
      changed = []
      changed << rewrite(VERSION_FILE) { "#{plan.version}\n" }
      changed << rewrite(DOCKERFILE) { |text| text.sub(/^ARG RUBY_VERSION=.*$/, "ARG RUBY_VERSION=#{plan.version}") }
      DOCS.each { |path| changed << rewrite(path) { |text| text.gsub(/Ruby \d+\.\d+\.\d+/, "Ruby #{plan.version}") } }
      Dir[root.join(WORKFLOWS).to_s].sort.each do |path|
        relative = Pathname(path).relative_path_from(root).to_s
        changed << rewrite(relative) { |text| text.gsub(SETUP_RUBY_PIN, "ruby/setup-ruby@#{plan.setup_ruby.sha} # #{plan.setup_ruby.tag}") }
      end
      changed.compact
    end

    private

    attr_reader :root

    # 中身が変わったときだけ書き、そのパスを返す
    def rewrite(path)
      file = root.join(path)
      return unless file.exist?

      before = file.read
      after = yield(before)
      return if after == before

      file.write(after)
      path
    end
  end
end
