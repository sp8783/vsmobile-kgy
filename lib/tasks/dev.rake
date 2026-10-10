namespace :dev do
  desc "開発用 DB のデータをすべて消し、seed とローカル確認用のサンプルデータを入れ直す（開発環境専用）"
  task sample_data: :environment do
    abort "dev:sample_data は開発環境でのみ実行できます" unless Rails.env.development?

    Rake::Task["db:truncate_all"].invoke
    Rake::Task["db:seed"].invoke
    summary = SampleData.new.call
    puts "\nサンプルデータを作成しました: ユーザー #{summary.users} 人 / イベント #{summary.events} 件 / 試合 #{summary.matches} 件"
    puts "  ログイン: sample_a 〜 sample_f（パスワード #{SampleData::PASSWORD}）、管理者は admin（パスワード password）"
  end

  namespace :sample_data do
    desc "イベントが 1 件もない（初回セットアップ直後の）ときだけ、サンプルデータを作る（bin/setup から呼ぶ）"
    task prepare: :environment do
      next unless Rails.env.development?

      if Event.exists?
        puts "データがあるため、サンプルデータの作成をスキップしました（作り直すときは bin/rails dev:sample_data）"
      else
        Rake::Task["dev:sample_data"].invoke
      end
    end
  end
end
