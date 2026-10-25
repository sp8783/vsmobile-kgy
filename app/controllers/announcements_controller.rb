class AnnouncementsController < ApplicationController
  before_action :authenticate_user!

  # お知らせのモーダルの「閉じる」。未読のお知らせは 1 つのモーダルにまとめて出しているので、まとめて既読にする
  def mark_all_as_read
    Announcement.unread_by(current_user).find_each do |announcement|
      current_user.user_announcement_reads.find_or_create_by!(announcement: announcement)
    end
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("announcement-modal") }
      format.html { redirect_back fallback_location: root_path }
    end
  end
end
