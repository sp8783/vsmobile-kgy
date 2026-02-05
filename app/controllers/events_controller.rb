class EventsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin, only: [:new, :create, :edit, :update, :destroy]
  before_action :set_event, only: [:show, :edit, :update, :destroy]

  def index
    @events = Event.includes(:matches).order(held_on: :desc)
  end

  def show
    @matches = @event.matches.includes(:event, match_players: [:user, :mobile_suit]).order(played_at: :desc)
    @rotations = @event.rotations.order(created_at: :desc)
  end

  def new
    @event = Event.new(held_on: Time.zone.today)
  end

  def create
    @event = Event.new(event_params)

    if @event.save
      redirect_to events_path, notice: "イベント「#{@event.name}」を作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @event.update(event_params)
      redirect_to events_path, notice: "イベント「#{@event.name}」を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    name = @event.name

    ActiveRecord::Base.transaction do
      # イベントに関連する試合のrotation_matchesの参照を解除
      match_ids = @event.matches.pluck(:id)
      RotationMatch.where(match_id: match_ids).update_all(match_id: nil) if match_ids.any?

      # イベントを削除（dependent: destroyでmatchesとrotationsも削除される）
      @event.destroy
    end

    redirect_to events_path, notice: "イベント「#{name}」を削除しました。"
  rescue => e
    redirect_to event_path(@event), alert: "削除に失敗しました: #{e.message}"
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.require(:event).permit(:name, :held_on, :description, :broadcast_url)
  end
end
