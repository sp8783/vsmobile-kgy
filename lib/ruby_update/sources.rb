require "net/http"

module RubyUpdate
  # Ruby の新版を判断するための外部の情報（GitHub は gh、Docker Hub は HTTP）
  class Sources
    SETUP_RUBY = "ruby/setup-ruby".freeze
    VERSIONS_FILE = "ruby-builder-versions.json".freeze

    def initialize(shell: CommandShell.new)
      @shell = shell
    end

    # ruby/setup-ruby の最新 release と、そのタグが指すコミット
    def latest_setup_ruby
      tag = JSON.parse(shell.capture("gh", "release", "view", "--repo", SETUP_RUBY, "--json", "tagName")).fetch("tagName")
      ref = JSON.parse(shell.capture("gh", "api", "repos/#{SETUP_RUBY}/git/ref/tags/#{tag}")).fetch("object")
      # annotated tag はタグオブジェクトを指すので、もう一段たどってコミットにする
      sha = ref["type"] == "tag" ? JSON.parse(shell.capture("gh", "api", "repos/#{SETUP_RUBY}/git/tags/#{ref['sha']}")).dig("object", "sha") : ref["sha"]
      Checker::SetupRuby.new(tag:, sha:)
    end

    # その release の setup-ruby が入れられる Ruby の版
    def available_versions(tag)
      json = shell.capture("gh", "api", "repos/#{SETUP_RUBY}/contents/#{VERSIONS_FILE}?ref=#{tag}", "-H", "Accept: application/vnd.github.raw")
      JSON.parse(json).fetch("ruby")
    end

    # Docker Hub に ruby:<版>-slim があるか（Dockerfile の base image）
    def image_exists?(version)
      uri = URI("https://hub.docker.com/v2/repositories/library/ruby/tags/#{version}-slim")
      Net::HTTP.get_response(uri).is_a?(Net::HTTPSuccess)
    end

    private

    attr_reader :shell
  end
end
