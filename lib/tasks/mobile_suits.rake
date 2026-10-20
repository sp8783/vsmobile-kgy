namespace :mobile_suits do
  desc "db/data/units.json の機体マスタを Wiki のページ ID で突き合わせて反映する（何度実行しても同じ結果。起動時にも自動実行）"
  task sync: :environment do
    result = MobileSuitCatalogSync.new.call
    puts "機体マスタを同期しました: 新規 #{result.created} 件 / 更新 #{result.updated} 件 / 変更なし #{result.unchanged} 件"
  end

  desc "Wiki から全機体を取り直し、変化があれば db/data/units.json と機体画像を書き換える（SCRAPER_DIR にスクレイパーの場所を指定）"
  task refresh: :environment do
    result = MobileSuitUpdate::Refresher.new(scraper_dir: ENV.fetch("SCRAPER_DIR")).call
    print_refresh_result(result)
  end

  namespace :update do
    desc "（GitHub Actions 用）取り直しの起点にするブランチ名を出力する（STANDALONE=1 で単独リリース）"
    task target: :environment do
      puts MobileSuitUpdate::Publisher.new(standalone: ENV["STANDALONE"] == "1").target.base
    end

    desc "（GitHub Actions 用）全機体を取り直し、機体データ更新の PR を作る・更新する・閉じる（STANDALONE=1 で単独リリース）"
    task publish: :environment do
      publisher = MobileSuitUpdate::Publisher.new(standalone: ENV["STANDALONE"] == "1")
      result = MobileSuitUpdate::Refresher.new(scraper_dir: ENV.fetch("SCRAPER_DIR")).call
      print_refresh_result(result)
      puts "機体データ更新の PR: #{publisher.publish(result)}"
    end
  end

  def print_refresh_result(result)
    diff = result.diff
    puts "新しい機体 #{diff.added.size} 機 / 変わった機体 #{diff.changed.size} 機 / 消えた機体 #{diff.removed.size} 機 / 並び順だけ変わった機体 #{diff.position_only_count} 機"
    diff.added.each { |suit| puts "  追加: #{MobileSuitUpdate::ReleaseText.added_line(suit)}" }
    diff.changed.each { |change| puts "  変更: #{MobileSuitUpdate::ReleaseText.change_line(change)}" }
    diff.removed.each { |suit| puts "  消えた: #{suit[:name]}" }
    diff.incomplete.each { |item| puts "  情報不足: #{item.suit[:name]}（#{item.missing.join('・')}）" }
    result.kept.each { |name| puts "  値が取れず今の値を残した: #{name}" }
  end
end
