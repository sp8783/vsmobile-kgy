namespace :release_notes do
  desc "config/release_notes の告知文のうち、未告知のバージョンをアプリ内お知らせと Discord に出す（起動時に自動実行）"
  task announce: :environment do
    ReleaseAnnouncer.new.call.each do |result|
      next unless result.announced || result.discord_posted

      puts "リリース告知 #{result.version}: お知らせ#{result.announced ? '公開' : '公開済み'} / Discord #{result.discord_posted ? '投稿' : '未投稿'}"
    end
  rescue => e
    # 告知の失敗でアプリの起動（デプロイ）を止めない
    Rails.logger.error("[release_notes:announce] #{e.class}: #{e.message}")
    warn "リリース告知に失敗しました: #{e.class}: #{e.message}"
  end
end
