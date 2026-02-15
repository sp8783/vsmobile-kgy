class EventsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin, only: [:new, :create, :edit, :update, :destroy, :edit_timestamps, :update_timestamps]
  before_action :set_event, only: [:show, :edit, :update, :destroy, :edit_timestamps, :update_timestamps]

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

  def parse_timestamp(str)
    return nil if str.blank?
    parts = str.strip.split(':').map(&:to_i)
    case parts.size
    when 3 then parts[0] * 3600 + parts[1] * 60 + parts[2]
    when 2 then parts[0] * 60 + parts[1]
    else nil
    end
  end

  def format_timestamp(seconds)
    return '' if seconds.nil?
    h, remainder = seconds.divmod(3600)
    m, s = remainder.divmod(60)
    "#{h}:#{format('%02d', m)}:#{format('%02d', s)}"
  end
end
