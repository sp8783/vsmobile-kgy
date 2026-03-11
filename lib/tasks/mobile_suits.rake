namespace :mobile_suits do
  desc "db/data/units.json から wiki_url・image_filename・スペック情報を MobileSuit レコードに書き込む"
  task import_data: :environment do
    json_path = Rails.root.join("db/data/units.json")
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
      metadata = unit["metadata"] || {}
      suit.update!(
        wiki_url:       unit["wikiUrl"],
        image_filename: image_filename,
        durability:     metadata["durability"]&.to_i.presence,
        bd_count:       metadata["bdCount"].presence,
        red_lock_range: metadata["redLockRange"].presence
      )
      updated += 1
    end

    puts "完了: #{updated} 件更新, #{skipped} 件スキップ"
  end
end
