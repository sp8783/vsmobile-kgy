module Admin
  class MobileSuitsController < BaseController
    before_action :set_mobile_suit, only: [:edit, :update, :destroy]

    def index
      @mobile_suits = MobileSuit.all.order(Arel.sql('position IS NULL, position ASC, cost DESC, name ASC'))
    end

    def new
      @mobile_suit = MobileSuit.new
    end

    def create
      @mobile_suit = MobileSuit.new(mobile_suit_params)

      if @mobile_suit.save
        redirect_to admin_mobile_suits_path, notice: "機体「#{@mobile_suit.name}」を登録しました。"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @mobile_suit.update(mobile_suit_params)
        redirect_to admin_mobile_suits_path, notice: "機体「#{@mobile_suit.name}」を更新しました。"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      name = @mobile_suit.name
      @mobile_suit.destroy
      redirect_to admin_mobile_suits_path, notice: "機体「#{name}」を削除しました。"
    end

    private

    def set_mobile_suit
      @mobile_suit = MobileSuit.find(params[:id])
    end

    def mobile_suit_params
      params.require(:mobile_suit).permit(:name, :series, :cost)
    end
  end
end
