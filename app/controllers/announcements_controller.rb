class AnnouncementsController < ApplicationController
  before_action :authenticate_user!

  def mark_as_read
    announcement = Announcement.find(params[:id])
    current_user.user_announcement_reads.find_or_create_by!(announcement: announcement)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("announcement-modal") }
      format.html { redirect_back fallback_location: root_path }
    end
  end
end
