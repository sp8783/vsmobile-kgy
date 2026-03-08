namespace :vsmobile do
  desc "units.json からwikiUrl・image_filenameをMobileSuitレコードに書き込む"
  task import_mobile_suit_data: :environment do
    json_path = Rails.root.join("../exvs2ib-wiki-scraper/output/units.json")
    unless File.exist?(json_path)
      abort "units.json が見つかりません: #{json_path}"
    end

    units = JSON.parse(File.read(json_path))["units"]
    puts "#{units.size} 件のデータを読み込みました"

    updated = 0
    skipped = 0

    units.each do |unit|
      # 全角/半角カッコ両方向でマッチング
      fullwidth_name = unit["name"].tr("()", "（）")
      suit = MobileSuit.find_by(name: unit["name"]) ||
             MobileSuit.find_by(name: fullwidth_name)

      unless suit
        puts "  スキップ（DBに存在しない）: #{unit['name']}"
        skipped += 1
        next
      end

      image_filename = File.basename(unit["imageLocalPath"])
      suit.update!(wiki_url: unit["wikiUrl"], image_filename: image_filename)
      updated += 1
    end

    puts "完了: #{updated} 件更新, #{skipped} 件スキップ"
  end


  desc "match_timeline が存在する全試合の survival_times を再計算する"
  task backfill_survival_times: :environment do
    matches = Match.joins(:match_timeline).includes(:match_timeline, match_players: :user)
    total   = matches.count
    puts "対象試合数: #{total}"

    # MatchStatsImportable の recalculate_timeline_derived_stats を再利用するため
    # 一時的にコントローラー風のコンテキストを作るのではなく、concern を直接 include したクラスを使う
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
