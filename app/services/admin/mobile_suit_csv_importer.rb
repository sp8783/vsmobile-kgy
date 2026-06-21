require "csv"

module Admin
  class MobileSuitCsvImporter
    Result = Struct.new(:imported_count, :updated_count, :errors, keyword_init: true) do
      def success?
        errors.empty?
      end

      def flash
        success? ? { notice: success_message } : { alert: "#{success_message} #{error_message}" }
      end

      def error_log_message
        return if success?

        "Mobile Suit Import Errors (#{errors.size} total): #{errors.join(' | ')}"
      end

      private

      def success_message
        "#{imported_count}件の機体を追加、#{updated_count}件を更新しました。"
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
    end

    def call
      imported_count = 0
      updated_count = 0
      errors = []
      position = 0

      CSV.foreach(file.path, headers: true, encoding: "UTF-8").with_index(2) do |row, line_number|
        begin
          mobile_suit = build_mobile_suit(row, position)
          if mobile_suit.new_record?
            mobile_suit.save!
            imported_count += 1
          else
            mobile_suit.save!
            updated_count += 1
          end
          position += 1
        rescue => e
          errors << "行#{line_number}: #{e.message}"
        end
      end

      Result.new(imported_count: imported_count, updated_count: updated_count, errors: errors)
    end

    private

    attr_reader :file

    def build_mobile_suit(row, position)
      mobile_suit_name = row["機体名"]
      raise "機体名が空です" if mobile_suit_name.blank?

      mobile_suit = MobileSuit.find_or_initialize_by(name: mobile_suit_name)
      mobile_suit.assign_attributes(
        cost: row["コスト"].to_i,
        series: row["シリーズ"],
        position: position
      )
      mobile_suit
    end
  end
end
