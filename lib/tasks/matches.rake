namespace :matches do
  desc "match_timeline が存在する全試合の survival_times を再計算する"
  task backfill_survival_times: :environment do
    matches = Match.joins(:match_timeline).includes(:match_timeline, match_players: :user)
    total   = matches.count
    puts "対象試合数: #{total}"

    runner = Class.new do
      include MatchStatsImportable
      attr_accessor :match

      def initialize(match)
        @match = match
      end
    end

    matches.find_each.with_index(1) do |match, i|
      runner.new(match).send(:recalculate_timeline_derived_stats)
      print "\r#{i}/#{total} 完了" if (i % 10).zero? || i == total
    end

    puts "\n完了"
  end
end
