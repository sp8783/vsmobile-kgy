class MatchesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event, only: [:new, :create]
  before_action :set_match, only: [:show, :edit, :update, :destroy]

  def index
    @matches = Match.includes(:event, :match_players => [:user, :mobile_suit]).order(played_at: :desc).page(params[:page]).per(20)
    @latest_event = Event.order(held_on: :desc).first
  end

  def show
  end

  def new
    @match = @event.matches.build(played_at: Time.current)
    4.times { |i| @match.match_players.build(position: i + 1) }
    @users = User.all.order(:nickname)
    @mobile_suits = MobileSuit.all.order(Arel.sql('position IS NULL, position ASC, cost DESC, name ASC'))
  end

  def create
    @match = @event.matches.build(match_params)
    @match.played_at = Time.current

    if @match.save
      redirect_to @event, notice: "対戦記録を登録しました。"
    else
      @users = User.all.order(:nickname)
      @mobile_suits = MobileSuit.all.order(Arel.sql('position IS NULL, position ASC, cost DESC, name ASC'))
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @users = User.all.order(:nickname)
    @mobile_suits = MobileSuit.all.order(Arel.sql('position IS NULL, position ASC, cost DESC, name ASC'))
  end

  def update
    if @match.update(match_params)
      redirect_to @match, notice: "対戦記録を更新しました。"
    else
      @users = User.all.order(:nickname)
      @mobile_suits = MobileSuit.all.order(Arel.sql('position IS NULL, position ASC, cost DESC, name ASC'))
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    event = @match.event
    @match.destroy
    redirect_to event_path(event), notice: "対戦記録を削除しました。"
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_match
    @match = Match.includes(:event, :match_players => [:user, :mobile_suit]).find(params[:id])
  end

  def match_params
    params.require(:match).permit(:winning_team, :played_at, match_players_attributes: [:id, :user_id, :mobile_suit_id, :team_number, :position])
  end
end
