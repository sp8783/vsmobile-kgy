module Admin
  class DiscordNoticesController < BaseController
    before_action :set_notices

    def index
    end

    def update
      kind = params[:kind]
      raise ActiveRecord::RecordNotFound unless DiscordNotice::KINDS.include?(kind)

      notice = @notices.find { |candidate| candidate.kind == kind }
      notice.assign_attributes(discord_notice_params)
      if notice.save
        redirect_to admin_discord_notices_path, notice: "「#{notice.label}」の投稿文を保存しました。"
      else
        render :index, status: :unprocessable_entity
      end
    end

    private

    def set_notices
      @notices = DiscordNotice::DISPLAY_KINDS.map { |kind| DiscordNotice.for(kind) }
      @preview_event = Event.where(held_on: Date.current..).order(:held_on, :id).first
    end

    # タイミングの行をすべて消したときは timings が送られないため、空にする
    def discord_notice_params
      permitted = params.require(:discord_notice).permit(:enabled, :body, timings: [ :days_before, :hour ])
      permitted[:timings] ||= []
      permitted
    end
  end
end
