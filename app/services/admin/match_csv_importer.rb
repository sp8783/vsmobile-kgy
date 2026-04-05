require "csv"
require "set"

module Admin
  class MatchCsvImporter
    Result = Struct.new(
      :imported_count,
      :created_event_count,
      :created_user_count,
      :errors,
      keyword_init: true
    ) do
      def success?
        errors.empty?
      end

      def flash
        success? ? { notice: success_message } : { alert: "#{success_message} #{error_message}" }
      end

      def error_log_message
        return if success?

        "CSV Import Errors (#{errors.size} total): #{errors.join(' | ')}"
      end

      private

      def success_message
        parts = [ "#{imported_count}件の試合データをインポートしました。" ]
        parts << "#{created_event_count}個のイベントを作成しました。" if created_event_count.positive?
        parts << "#{created_user_count}人のユーザーを作成しました。" if created_user_count.positive?
        parts.join(" ")
      end

      def error_message
        summary = errors.first(5).join(", ")
        message = "#{errors.size}件のエラーがありました。"
        message += " 最初の5件: #{summary}" if summary.present?
        message += " 詳細はログを確認してください。" if errors.size > 5
        message
      end
    end

    def initialize(file:)
      @file = file
      @created_events = Set.new
      @created_users = Set.new
      @next_generated_user_number = nil
    end

    def call
      imported_count = 0
      errors = []

      CSV.foreach(file.path, headers: true, encoding: "UTF-8").with_index(2) do |row, line_number|
        begin
          event = find_or_create_event(row["日付"], line_number)
          track_potential_new_users(row)
          import_match(row, event)
          imported_count += 1
        rescue => e
          errors << "行#{line_number}: #{e.message}"
        end
      end

      Result.new(
        imported_count: imported_count,
        created_event_count: created_events.size,
        created_user_count: created_users.size,
        errors: errors
      )
    end

    private

    attr_reader :file, :created_events, :created_users

    def find_or_create_event(date_text, line_number)
      played_at = parse_date(date_text) + (line_number - 1).seconds
      event_date = played_at.to_date

      event = Event.find_or_initialize_by(held_on: event_date)
      return event unless event.new_record?

      event.name = "#{event_date.strftime('%Y/%m/%d')} 対戦会"
      event.save!
      created_events << event.name
      event
    end

    def track_potential_new_users(row)
      player_names(row).each do |player_name|
        created_users << player_name unless User.exists?(nickname: player_name)
      end
    end

    def import_match(row, event)
      match = event.matches.build(
        played_at: parse_date(row["日付"]),
        winning_team: row["勝敗1"].to_i == 1 ? 1 : 2
      )

      player_rows(row).each do |player_data|
        match.match_players.build(
          user: find_or_create_user(player_data[:nickname]),
          mobile_suit: find_mobile_suit!(player_data[:mobile_suit_name]),
          team_number: player_data[:team_number],
          position: player_data[:position]
        )
      end

      match.save!
    end

    def player_rows(row)
      [
        { nickname: row["プレイヤー1"], mobile_suit_name: row["使用機体1"], team_number: 1, position: 1 },
        { nickname: row["プレイヤー2"], mobile_suit_name: row["使用機体2"], team_number: 1, position: 2 },
        { nickname: row["プレイヤー3"], mobile_suit_name: row["使用機体3"], team_number: 2, position: 3 },
        { nickname: row["プレイヤー4"], mobile_suit_name: row["使用機体4"], team_number: 2, position: 4 }
      ]
    end

    def player_names(row)
      player_rows(row).map { |player_data| player_data[:nickname] }
    end

    def find_or_create_user(nickname)
      User.find_or_create_by(nickname: nickname) do |user|
        user.username = next_generated_username
        user.password = "password"
        user.password_confirmation = "password"
        user.is_admin = false
        user.notification_enabled = false
      end
    end

    def next_generated_username
      @next_generated_user_number ||= begin
        User.where("username LIKE 'user_%'")
            .pluck(:username)
            .filter_map { |name| name.delete_prefix("user_").to_i if /\Auser_\d+\z/.match?(name) }
            .max
            .to_i + 1
      end

      username = "user_#{@next_generated_user_number}"
      @next_generated_user_number += 1
      username
    end

    def find_mobile_suit!(mobile_suit_name)
      MobileSuit.find_by(name: mobile_suit_name).tap do |mobile_suit|
        raise "機体「#{mobile_suit_name}」が見つかりません" unless mobile_suit
      end
    end

    def parse_date(date_str)
      if date_str =~ /(\d{4})[\/\-年](\d{1,2})[\/\-月](\d{1,2})/
        year, month, day = ::Regexp.last_match.captures.map(&:to_i)
        Time.zone.local(year, month, day, 0, 0, 0)
      else
        raise "日付の形式が不正です: #{date_str}"
      end
    end
  end
end
