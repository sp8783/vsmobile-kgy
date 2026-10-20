module Admin
  class DiscordChannelsController < BaseController
    def index
      @channels = DiscordChannel::PURPOSES.map { |p| DiscordChannel.find_or_initialize_by(purpose: p) }
    end

    def update
      @channel = DiscordChannel.find_or_initialize_by(purpose: params[:purpose])
      if @channel.update(discord_channel_params)
        redirect_to admin_discord_channels_path, notice: "「#{@channel.purpose_label}」チャンネルの設定を保存しました。#{post_pending_release_announcements}"
      else
        @channels = DiscordChannel::PURPOSES.map { |p| DiscordChannel.find_or_initialize_by(purpose: p) }
        render :index, status: :unprocessable_entity
      end
    end

    private

    # リリース告知の投稿先を設定したら、まだ Discord に出していない告知（作成から 3 日以内）を投稿する
    def post_pending_release_announcements
      return unless @channel.purpose == "release" && @channel.webhook_url.present?

      posted = ReleaseAnnouncer.new.call.count(&:discord_posted)
      posted.positive? ? "未投稿だったリリース告知を #{posted} 件投稿しました。" : nil
    end

    def discord_channel_params
      params.require(:discord_channel).permit(:webhook_url, :label)
    end
  end
end
