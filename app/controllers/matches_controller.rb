class MatchesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event, only: [:new, :create]

  def index
    @matches = Match.includes(:event, :match_players => [:user, :mobile_suit]).order(played_at: :desc).page(params[:page]).per(20)
  end

  def show
    @match = Match.includes(:event, :match_players => [:user, :mobile_suit]).find(params[:id])
  end

  def new
    @match = @event.matches.build(played_at: Time.current)
    4.times { |i| @match.match_players.build(position: i + 1) }
    @users = User.all.order(:nickname)
    @mobile_suits = MobileSuit.all.order(:cost, :name)
  end

  def create
    @match = @event.matches.build(match_params)
    @match.played_at = Time.current

    if @match.save
      redirect_to @event, notice: "試合記録を登録しました。"
    else
      @users = User.all.order(:nickname)
      @mobile_suits = MobileSuit.all.order(:cost, :name)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def match_params
    params.require(:match).permit(:winning_team, match_players_attributes: [:user_id, :mobile_suit_id, :team_number, :position])
  end
end
