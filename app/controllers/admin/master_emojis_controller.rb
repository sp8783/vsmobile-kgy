module Admin
  class MasterEmojisController < BaseController
    before_action :set_master_emoji, only: [:edit, :update, :destroy]

    def index
      @master_emojis = MasterEmoji.ordered.includes(:reactions)
    end

    def new
      @master_emoji = MasterEmoji.new
    end

    def create
      @master_emoji = MasterEmoji.new(master_emoji_params)

      if @master_emoji.save
        redirect_to admin_master_emojis_path, notice: "スタンプ「#{@master_emoji.name}」を登録しました。"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @master_emoji.update(master_emoji_params)
        redirect_to admin_master_emojis_path, notice: "スタンプ「#{@master_emoji.name}」を更新しました。"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      name = @master_emoji.name
      @master_emoji.destroy
      redirect_to admin_master_emojis_path, notice: "スタンプ「#{name}」を削除しました。"
    end

    private

    def set_master_emoji
      @master_emoji = MasterEmoji.find(params[:id])
    end

    def master_emoji_params
      params.require(:master_emoji).permit(:name, :image_key, :position, :is_active)
    end
  end
end
