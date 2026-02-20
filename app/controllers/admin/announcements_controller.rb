module Admin
  class AnnouncementsController < BaseController
    before_action :set_announcement, only: [ :edit, :update, :destroy ]

    def index
      @announcements = Announcement.order(published_at: :desc)
    end

    def new
      @announcement = Announcement.new(published_at: Time.current)
    end

    def create
      @announcement = Announcement.new(announcement_params)
      if @announcement.save
        redirect_to admin_announcements_path, notice: "お知らせ「#{@announcement.title}」を作成しました。"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @announcement.update(announcement_params)
        redirect_to admin_announcements_path, notice: "お知らせ「#{@announcement.title}」を更新しました。"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      title = @announcement.title
      @announcement.destroy
      redirect_to admin_announcements_path, notice: "お知らせ「#{title}」を削除しました。"
    end

    private

    def set_announcement
      @announcement = Announcement.find(params[:id])
    end

    def announcement_params
      params.require(:announcement).permit(:title, :body, :published_at, :expires_at, :is_active)
    end
  end
end
