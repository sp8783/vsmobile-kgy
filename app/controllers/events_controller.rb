require "net/http"

class EventsController < ApplicationController
  include TimestampParseable
  before_action :authenticate_user!
  before_action :require_admin, only: [:new, :create, :edit, :update, :destroy, :edit_timestamps, :update_timestamps, :trigger_analysis]
  before_action :set_event, only: [:show, :edit, :update, :destroy, :edit_timestamps, :update_timestamps, :trigger_analysis]

  def index
    @events = Event.includes(:matches).order(held_on: :desc)
  end

  def show
    @matches = @event.matches.includes(:event, :rotation_match, match_players: [:user, :mobile_suit], reactions: :user).order(played_at: :asc, id: :asc)
    @rotations = @event.rotations.order(created_at: :asc)
    @emojis = MasterEmoji.active.ordered
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
    @matches = @event.matches.includes(match_players: [:user, :mobile_suit]).order(:played_at, :id)
    existing = @matches.map { |m| format_timestamp(m.video_timestamp) }
    @timestamps_text = existing.any?(&:present?) ? existing.join("\n") : ''
  end

  def update_timestamps
    @matches = @event.matches.includes(match_players: [:user, :mobile_suit]).order(:played_at, :id)
    raw_text = params[:timestamps].to_s
    lines = raw_text.split("\n").map(&:strip)

    # 末尾の空行を除去
    lines.pop while lines.last&.empty?

    if lines.size != @matches.size
      flash.now[:alert] = "行数（#{lines.size}）と試合数（#{@matches.size}）が一致しません。"
      @timestamps_text = raw_text
      render :edit_timestamps, status: :unprocessable_entity
      return
    end

    timestamps = lines.map.with_index do |line, i|
      if line.blank?
        flash.now[:alert] = "#{i + 1}行目が空です。すべての行にタイムスタンプを入力してください。"
        @timestamps_text = raw_text
        render :edit_timestamps, status: :unprocessable_entity
        return
      end
      seconds = parse_timestamp(line)
      if seconds.nil?
        flash.now[:alert] = "#{i + 1}行目「#{line}」の形式が不正です。H:MM:SS または MM:SS の形式で入力してください。"
        @timestamps_text = raw_text
        render :edit_timestamps, status: :unprocessable_entity
        return
      end
      seconds
    end

    ActiveRecord::Base.transaction do
      @matches.each_with_index do |match, i|
        match.update!(video_timestamp: timestamps[i])
      end
    end

    redirect_to event_path(@event), notice: "タイムスタンプを保存しました。"
  end

  def trigger_analysis
    repo = ENV["GITHUB_REPO"].presence
    workflow_id = ENV["GITHUB_WORKFLOW_ID"].presence
    token = ENV["GITHUB_TOKEN"].presence

    if repo.blank? || workflow_id.blank? || token.blank?
      return redirect_to event_path(@event), alert: "GitHub Actions の設定が不完全です（GITHUB_REPO / GITHUB_WORKFLOW_ID / GITHUB_TOKEN を確認してください）。"
    end

    uri = URI("https://api.github.com/repos/#{repo}/actions/workflows/#{workflow_id}/dispatches")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Post.new(uri.path, {
      "Authorization" => "Bearer #{token}",
      "Accept" => "application/vnd.github+json",
      "Content-Type" => "application/json",
      "X-GitHub-Api-Version" => "2022-11-28"
    })
    req.body = {
      ref: "main",
      inputs: {
        event_id: @event.id.to_s,
        broadcast_url: @event.broadcast_url
      }
    }.to_json

    res = http.request(req)

    if res.is_a?(Net::HTTPNoContent)
      redirect_to event_path(@event), notice: "解析を開始しました。完了後にタイムスタンプが自動登録されます。"
    else
      redirect_to event_path(@event), alert: "GitHub Actions のトリガーに失敗しました（HTTP #{res.code}）。"
    end
  rescue => e
    redirect_to event_path(@event), alert: "解析開始でエラーが発生しました: #{e.message}"
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
