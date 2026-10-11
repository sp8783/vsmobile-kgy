namespace :release do
  desc "（GitHub Actions 用）リリース PR のデプロイ成功後に、タグ・GitHub Release を作り、Issue を閉じて GitHub Project を Done にする（SHA にデプロイしたコミット）"
  task finalize: :environment do
    result = ReleaseFinalizer.new(sha: ENV.fetch("SHA"), repo: ENV.fetch("GITHUB_REPOSITORY"), project_token: ENV["PROJECT_TOKEN"]).call
    next unless result

    puts "#{result.version}: タグ#{result.tagged ? 'を作成' : '作成済み'} / GitHub Release #{result.released ? 'を作成' : '作成済み'} / " \
         "Issue を閉じた: #{result.closed_issues.map { |n| "##{n}" }.join(' ').presence || 'なし'} / Project を Done: #{result.done_issues.map { |n| "##{n}" }.join(' ').presence || 'なし'}"
  end
end
