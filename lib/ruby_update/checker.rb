module RubyUpdate
  # 今の Ruby と、使える新しい版を比べて、何を上げるかを決める
  #
  # - 候補は ruby/setup-ruby が知っている正式版（preview / rc は除く）のうち、Docker Hub に ruby:<版>-slim があるもの
  #   （CI・Deploy は setup-ruby、本番のイメージは Dockerfile の ruby:<版>-slim を使うため、両方そろって初めて上げられる）
  # - 同じ major.minor の最新があれば patch。なければ、より新しい minor / major の最新があれば minor（下書きの PR にする）
  class Checker
    SetupRuby = Data.define(:tag, :sha)
    # kind: :patch / :minor / :none。version は上げる先（:none のときは今の版）
    Plan = Data.define(:kind, :version, :setup_ruby) do
      def none? = kind == :none
      def draft? = kind == :minor
    end

    STABLE = /\A\d+\.\d+\.\d+\z/

    # image_exists: 版（"4.0.11"）を受け取り、Docker Hub にイメージがあれば true を返す
    def initialize(current:, available:, setup_ruby:, image_exists:)
      @current = Gem::Version.new(current)
      @available = available
      @setup_ruby = setup_ruby
      @image_exists = image_exists
    end

    def plan
      patch = newer.find { |version| same_minor?(version) && image_exists.call(version.to_s) }
      return Plan.new(kind: :patch, version: patch.to_s, setup_ruby:) if patch

      minor = newer.find { |version| !same_minor?(version) && image_exists.call(version.to_s) }
      return Plan.new(kind: :minor, version: minor.to_s, setup_ruby:) if minor

      Plan.new(kind: :none, version: current.to_s, setup_ruby:)
    end

    private

    attr_reader :current, :available, :setup_ruby, :image_exists

    # 今より新しい正式版を、新しい順に
    def newer
      @newer ||= available.grep(STABLE).map { |version| Gem::Version.new(version) }.select { |version| version > current }.sort.reverse
    end

    def same_minor?(version)
      version.segments.first(2) == current.segments.first(2)
    end
  end
end
