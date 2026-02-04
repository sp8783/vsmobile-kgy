require 'csv'

module Admin
  class ImportsController < BaseController

    def new
    end

    def create
      unless params[:file].present?
        redirect_to new_admin_import_path, alert: "CSVファイルを選択してください。"
        return
      end

      file = params[:file]

      begin
        imported_count = 0
        errors = []
        created_events = []
        created_users = Set.new
        row_number = 0

        CSV.foreach(file.path, headers: true, encoding: 'UTF-8') do |row|
          begin
            row_number += 1
            # 日付からイベントを取得または作成
            # 試合の順序を保持するため、行番号を秒として加算
            played_at = parse_date(row['日付']) + row_number.seconds
            event_date = played_at.to_date

            event = Event.find_or_create_by(held_on: event_date) do |e|
              e.name = "#{event_date.strftime('%Y/%m/%d')} 対戦会"
              created_events << e.name unless created_events.include?(e.name)
            end

            # インポート前にユーザーをカウント
            before_import = ->(player_name) {
              unless User.exists?(nickname: player_name)
                created_users << player_name
              end
            }
            [row['プレイヤー1'], row['プレイヤー2'], row['プレイヤー3'], row['プレイヤー4']].each(&before_import)

            import_match(row, event)
            imported_count += 1
          rescue => e
            errors << "行#{$.}: #{e.message}"
          end
        end

        message_parts = []
        message_parts << "#{imported_count}件の試合データをインポートしました。"
        message_parts << "#{created_events.size}個のイベントを作成しました。" if created_events.any?
        message_parts << "#{created_users.size}人のユーザーを作成しました。" if created_users.any?

        if errors.any?
          error_summary = errors.first(5).join(', ')
          error_message = "#{errors.size}件のエラーがありました。"
          error_message += " 最初の5件: #{error_summary}" if errors.size > 0
          error_message += " 詳細はログを確認してください。" if errors.size > 5

          flash[:alert] = message_parts.join(' ') + " " + error_message
          # エラー詳細はログに出力
          Rails.logger.error("CSV Import Errors (#{errors.size} total): #{errors.join(' | ')}")
        else
          flash[:notice] = message_parts.join(' ')
        end

        redirect_to events_path
      rescue => e
        redirect_to new_admin_import_path, alert: "CSVファイルの読み込みに失敗しました: #{e.message}"
      end
    end

    def new_mobile_suits
    end

    def import_mobile_suits
      unless params[:file].present?
        redirect_to new_mobile_suits_admin_imports_path, alert: "CSVファイルを選択してください。"
        return
      end

      file = params[:file]

      begin
        imported_count = 0
        updated_count = 0
        errors = []
        position = 0

        CSV.foreach(file.path, headers: true, encoding: 'UTF-8') do |row|
          begin
            mobile_suit_name = row['機体名']
            cost = row['コスト'].to_i
            series = row['シリーズ']

            if mobile_suit_name.blank?
              errors << "行#{$.}: 機体名が空です"
              next
            end

            mobile_suit = MobileSuit.find_or_initialize_by(name: mobile_suit_name)
            if mobile_suit.new_record?
              mobile_suit.cost = cost
              mobile_suit.series = series
              mobile_suit.position = position
              mobile_suit.save!
              imported_count += 1
            else
              mobile_suit.update!(cost: cost, series: series, position: position)
              updated_count += 1
            end

            position += 1
          rescue => e
            errors << "行#{$.}: #{e.message}"
          end
        end

        if errors.any?
          error_summary = errors.first(5).join(', ')
          error_message = "#{errors.size}件のエラーがありました。"
          error_message += " 最初の5件: #{error_summary}" if errors.size > 0
          error_message += " 詳細はログを確認してください。" if errors.size > 5

          flash[:alert] = "#{imported_count}件追加、#{updated_count}件更新しました。 " + error_message
          # エラー詳細はログに出力
          Rails.logger.error("Mobile Suit Import Errors (#{errors.size} total): #{errors.join(' | ')}")
        else
          flash[:notice] = "#{imported_count}件の機体を追加、#{updated_count}件を更新しました。"
        end

        redirect_to mobile_suits_path
      rescue => e
        redirect_to new_mobile_suits_admin_imports_path, alert: "CSVファイルの読み込みに失敗しました: #{e.message}"
      end
    end

    private

    def import_match(row, event)
      # CSVの列: 日付, プレイヤー1, 使用機体1, プレイヤー2, 使用機体2, プレイヤー3, 使用機体3, プレイヤー4, 使用機体4, 勝敗1, 勝敗2, 勝敗3, 勝敗4
      played_at = parse_date(row['日付'])

      # プレイヤーと機体の取得
      players_data = [
        { nickname: row['プレイヤー1'], mobile_suit_name: row['使用機体1'], result: row['勝敗1'], position: 1 },
        { nickname: row['プレイヤー2'], mobile_suit_name: row['使用機体2'], result: row['勝敗2'], position: 2 },
        { nickname: row['プレイヤー3'], mobile_suit_name: row['使用機体3'], result: row['勝敗3'], position: 3 },
        { nickname: row['プレイヤー4'], mobile_suit_name: row['使用機体4'], result: row['勝敗4'], position: 4 }
      ]

      # 勝利チームの判定（勝敗1が"1"ならチーム1の勝利、"0"ならチーム2の勝利）
      winning_team = row['勝敗1'].to_i == 1 ? 1 : 2

      # チーム分け（1-2 vs 3-4）
      players_data[0][:team_number] = 1
      players_data[1][:team_number] = 1
      players_data[2][:team_number] = 2
      players_data[3][:team_number] = 2

      # 試合の作成
      match = event.matches.build(
        played_at: played_at,
        winning_team: winning_team
      )

      # プレイヤーの追加
      players_data.each do |player_data|
        # ユーザーを検索、存在しない場合は自動作成
        user = User.find_or_create_by(nickname: player_data[:nickname]) do |u|
          # 連番でusernameを自動生成（user_1, user_2, ...）
          max_user_number = User.where("username LIKE 'user_%'")
                                 .pluck(:username)
                                 .map { |name| name.sub('user_', '').to_i }
                                 .max || 0
          u.username = "user_#{max_user_number + 1}"
          u.password = 'password'
          u.password_confirmation = 'password'
          u.is_admin = false
          u.notification_enabled = false
        end

        mobile_suit = MobileSuit.find_by(name: player_data[:mobile_suit_name])
        raise "機体「#{player_data[:mobile_suit_name]}」が見つかりません" unless mobile_suit

        match.match_players.build(
          user: user,
          mobile_suit: mobile_suit,
          team_number: player_data[:team_number],
          position: player_data[:position]
        )
      end

      match.save!
    end

    def parse_date(date_str)
      # 日付のパース（複数フォーマット対応）
      if date_str =~ /(\d{4})[\/\-年](\d{1,2})[\/\-月](\d{1,2})/
        year, month, day = $1.to_i, $2.to_i, $3.to_i
        Time.zone.local(year, month, day, 0, 0, 0) # 00:00:00から開始（行番号を秒として加算する）
      else
        raise "日付の形式が不正です: #{date_str}"
      end
    end
  end
end
