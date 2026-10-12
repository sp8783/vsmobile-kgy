class EventsController < ApplicationController
  include TimestampParseable

  before_action :authenticate_user!
  before_action :require_admin, only: [ :new, :create, :edit, :update, :destroy, :edit_timestamps, :update_timestamps, :update_first_match_timestamp, :trigger_analysis, :trigger_scraping, :post_broadcast_to_discord ]
  before_action :set_event, only: [ :show, :edit, :update, :destroy, :edit_timestamps, :update_timestamps, :update_first_match_timestamp, :trigger_analysis, :trigger_scraping, :post_broadcast_to_discord ]

  def index
    @events = Event.includes(:matches).order(held_on: :desc)
  end

  def show
    assign_view_state(EventMatchListing.new(event: @event, params: params, viewing_as_user: viewing_as_user).to_h)
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

  def edit_timestamps
    timestamp_batch = EventTimestampBatch.new(event: @event)
    @matches = timestamp_batch.matches
    @timestamps_text = timestamp_batch.existing_text
    assign_first_match_timestamp_state
  end

  def update_timestamps
    timestamp_batch = EventTimestampBatch.new(event: @event)
    @matches = timestamp_batch.matches
    result = timestamp_batch.update(params[:timestamps].to_s)

    if result.success?
      redirect_to event_path(@event), notice: "タイムスタンプを保存しました。"
    else
      flash.now[:alert] = result.error_message
      @timestamps_text = result.timestamps_text
      assign_first_match_timestamp_state
      render :edit_timestamps, status: :unprocessable_entity
    end
  end

  # 1試合目の配信上の時刻を保存し、試合の開始時刻を取り込んでいれば全試合のタイムスタンプを計算する
  def update_first_match_timestamp
    text = params[:first_match_video_timestamp].to_s.strip
    seconds = parse_timestamp(text)
    if text.present? && seconds.nil?
      return redirect_to edit_timestamps_event_path(@event), alert: "1試合目の配信上の時刻「#{text}」の形式が不正です。H:MM:SS または MM:SS の形式で入力してください。"
    end

    @event.update!(first_match_video_timestamp: seconds)
    count = EventTimestampCalculator.new(event: @event).apply!
    notice =
      if count
        "#{count} 試合のタイムスタンプを、試合の開始時刻から計算して保存しました。"
      elsif seconds
        "1試合目の配信上の時刻を保存しました。統計を取り込んだあとに、全試合のタイムスタンプを計算します。"
      else
        "1試合目の配信上の時刻を消しました。"
      end
    redirect_to edit_timestamps_event_path(@event), notice: notice
  end

  def trigger_analysis
    dispatch_result = GithubActionsWorkflowDispatcher.new(
      repo: ENV["GITHUB_REPO"].presence,
      workflow_id: ENV["GITHUB_WORKFLOW_ID"].presence,
      token: ENV["GITHUB_TOKEN"].presence,
      inputs: {
        event_id: @event.id.to_s,
        broadcast_url: @event.broadcast_url
      },
      missing_config_message: "GitHub Actions の設定が不完全です（GITHUB_REPO / GITHUB_WORKFLOW_ID / GITHUB_TOKEN を確認してください）。",
      exception_message_prefix: "解析開始でエラーが発生しました"
    ).call

    if dispatch_result.success?
      redirect_to event_path(@event), notice: "解析を開始しました。完了後にタイムスタンプが自動登録されます。"
    else
      redirect_to event_path(@event), alert: dispatch_result.error_message
    end
  end

  def trigger_scraping
    dispatch_result = GithubActionsWorkflowDispatcher.new(
      repo: ENV["SCRAPER_GITHUB_REPO"].presence,
      workflow_id: ENV["SCRAPER_GITHUB_WORKFLOW_ID"].presence,
      token: ENV["GITHUB_TOKEN"].presence,
      inputs: {
        event_id: @event.id.to_s
      },
      missing_config_message: "スクレイパーの設定が不完全です（SCRAPER_GITHUB_REPO / SCRAPER_GITHUB_WORKFLOW_ID / GITHUB_TOKEN を確認してください）。",
      exception_message_prefix: "スクレイピング開始でエラーが発生しました"
    ).call

    if dispatch_result.success?
      redirect_to event_path(@event), notice: "統計スクレイピングを開始しました。完了後に統計データが自動登録されます。"
    else
      redirect_to event_path(@event), alert: dispatch_result.error_message
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

  # タイムスタンプ一括設定の画面の「1試合目の配信上の時刻」の欄
  def assign_first_match_timestamp_state
    @timestamp_calculator = EventTimestampCalculator.new(event: @event)
    @first_match_video_timestamp_text = format_timestamp(@event.first_match_video_timestamp)
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
