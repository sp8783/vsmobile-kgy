module Admin
  class DiscordChannelsController < BaseController
    def index
      @channels = DiscordChannel::PURPOSES.map { |p| DiscordChannel.find_or_initialize_by(purpose: p) }
    end

    def update
      @channel = DiscordChannel.find_or_initialize_by(purpose: params[:purpose])
      if @channel.update(discord_channel_params)
        redirect_to admin_discord_channels_path, notice: "「#{@channel.purpose_label}」チャンネルの設定を保存しました。"
      else
        @channels = DiscordChannel::PURPOSES.map { |p| DiscordChannel.find_or_initialize_by(purpose: p) }
        render :index, status: :unprocessable_entity
      end
    end

    private

    def discord_channel_params
      params.require(:discord_channel).permit(:webhook_url, :label)
    end
  end
end
