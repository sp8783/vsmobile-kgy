class EventsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin, only: [ :new, :create, :edit, :update, :destroy, :post_broadcast_to_discord ]
  before_action :set_event, only: [ :show, :edit, :update, :destroy, :post_broadcast_to_discord ]

  def index
    @events = Event.includes(:matches).order(held_on: :desc)
  end

  def show
    assign_view_state(EventMatchListing.new(event: @event, params: params, viewing_as_user: viewing_as_user).to_h)
    assign_data_status if current_user.is_admin?
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

  def post_broadcast_to_discord
    if @event.broadcast_url.blank?
      return redirect_to event_path(@event), alert: "配信URLが設定されていません。"
    end

    message = @event.broadcast_url
    DiscordWebhookService.post(purpose: "broadcast_url", message: message)
    redirect_to event_path(@event), notice: "Discordへ配信URLを投稿しました。"
  end

  def destroy
    result = EventDeletionWorkflow.new(event: @event).call

    if result.success?
      redirect_to events_path, notice: "イベント「#{result.event_name}」を削除しました。"
    else
      redirect_to event_path(@event), alert: "削除に失敗しました: #{result.error_message}"
    end
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  # 対戦会のあとに登録するデータ（アーカイブのタイムスタンプ・試合の統計）の登録状況
  def assign_data_status
    matches = @event.matches
    @data_status = {
      total: matches.count,
      timestamps: matches.where.not(video_timestamp: nil).count,
      stats: matches.joins(:match_timeline).count
    }
  end

  def assign_view_state(attributes)
    attributes.each do |name, value|
      instance_variable_set("@#{name}", value)
    end
  end

  def event_params
    params.require(:event).permit(:name, :held_on, :description, :broadcast_url, :discord_thread_url)
  end
end
