namespace :mobile_suits do
  desc "db/data/units.json の機体マスタを Wiki のページ ID で突き合わせて反映する（何度実行しても同じ結果。起動時にも自動実行）"
  task sync: :environment do
    result = MobileSuitCatalogSync.new.call
    puts "機体マスタを同期しました: 新規 #{result.created} 件 / 更新 #{result.updated} 件 / 変更なし #{result.unchanged} 件"
  end
end
