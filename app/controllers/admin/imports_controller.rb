module Admin
  class ImportsController < BaseController
    def new
    end

    def create
      unless params[:file].present?
        redirect_to new_admin_import_path, alert: "CSVファイルを選択してください。"
        return
      end

      begin
        result = Admin::MatchCsvImporter.new(file: params[:file]).call
        Rails.logger.error(result.error_log_message) if result.error_log_message
        flash.update(result.flash)
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

      begin
        result = Admin::MobileSuitCsvImporter.new(file: params[:file]).call
        Rails.logger.error(result.error_log_message) if result.error_log_message
        flash.update(result.flash)
        redirect_to admin_mobile_suits_path
      rescue => e
        redirect_to new_mobile_suits_admin_imports_path, alert: "CSVファイルの読み込みに失敗しました: #{e.message}"
      end
    end
  end
end
