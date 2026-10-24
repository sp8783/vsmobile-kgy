class EventsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin, only: [ :new, :create, :edit, :update, :destroy, :post_broadcast_to_discord, :announce_data_to_discord ]
  before_action :set_event, only: [ :show, :edit, :update, :destroy, :post_broadcast_to_discord, :announce_data_to_discord ]

  def index
    @events = Event.includes(:matches).order(held_on: :desc)
  end

  def show
    assign_view_state(EventMatchListing.new(event: @event, params: params, viewing_as_user: viewing_as_user).to_h)
    assign_data_status if current_user.is_admin?
    assign_stats_coverage
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

    if DiscordWebhookService.post(purpose: "broadcast_url", message: @event.broadcast_url)
      redirect_to event_path(@event), notice: "Discordへ配信URLを投稿しました。"
    else
      redirect_to event_path(@event), alert: "Discord への投稿に失敗しました。「配信URL投稿」の投稿先の設定を確認してください。"
    end
  end

  # 統計・タイムスタンプがそろっているのにまだ知らせていないときの予備（ふだんは登録のあとに自動で知らせる）
  def announce_data_to_discord
    announcer = EventDataAnnouncer.new(event: @event)
    result = announcer.announce!

    if result.posted?
      redirect_to event_path(@event), notice: "Discord のフォーラムの記事に、#{announcer.labels(result.kinds)}の登録を知らせました。"
    else
      redirect_to event_path(@event), alert: result.error_message
    end
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

  # 対戦会のあとに登録するデータ（配信アーカイブのタイムスタンプ・各試合の統計）の登録状況
  def assign_data_status
    matches = @event.matches
    @data_status = {
      total: matches.count,
      timestamps: matches.where.not(video_timestamp: nil).count,
      stats: matches.joins(:match_timeline).count
    }
    @data_announcer = EventDataAnnouncer.new(event: @event)
  end

  # VS.モバイル連携: 各試合の統計データの集まり具合。対戦会のあと 30 日のあいだ、まだ全試合そろっていないときだけ出す。
  # 管理者（視点切り替え中でない）には誰が送ったかの一覧、それ以外には本人への呼びかけ（視点切り替え中はその人のもの）
  def assign_stats_coverage
    return if viewing_as_user.is_guest || @event.held_on < Api::Vsmobile::TargetsController::RETENTION_DAYS.days.ago.to_date

    coverage = Vsmobile::Coverage.new(event: @event)
    return unless coverage.total.positive? && !coverage.complete?

    @coverage = coverage
    @coverage_mode = current_user.is_admin? && !viewing_as_someone_else? ? :admin : :viewer
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
