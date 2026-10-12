module Events
  # イベントのアーカイブのタイムスタンプ（配信で各試合が何秒目か）の登録。
  # 登録のしかたは 3 つ: 試合の開始時刻から計算する・動画を解析する・手で入力する
  class TimestampsController < ApplicationController
    include TimestampParseable

    TABS = %w[calculate analysis manual].freeze

    before_action :authenticate_user!
    before_action :require_admin
    before_action :set_event

    def show
      @timestamps_text = timestamp_batch.existing_text
      assign_show_state
    end

    # 手で入力したタイムスタンプ（1行1試合）を保存する
    def update
      result = timestamp_batch.update(params[:timestamps].to_s)

      if result.success?
        redirect_to event_timestamps_path(@event, tab: "manual"), notice: "タイムスタンプを保存しました。"
      else
        flash.now[:alert] = result.error_message
        @timestamps_text = result.timestamps_text
        assign_show_state(tab: "manual")
        render :show, status: :unprocessable_entity
      end
    end

    # 1試合目の配信上の時刻を保存し、試合の開始時刻を取り込んでいれば全試合のタイムスタンプを計算する
    def first_match
      text = params[:first_match_video_timestamp].to_s.strip
      seconds = parse_timestamp(text)
      if text.present? && seconds.nil?
        return redirect_to event_timestamps_path(@event, tab: "calculate"),
                           alert: "1試合目の配信上の時刻「#{text}」の形式が不正です。H:MM:SS または MM:SS の形式で入力してください。"
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
      redirect_to event_timestamps_path(@event, tab: "calculate"), notice: notice
    end

    # 配信のアーカイブの動画解析（exvs2ib-replay-parser）を GitHub Actions で始める
    def analysis
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
        redirect_to event_timestamps_path(@event, tab: "analysis"), notice: "解析を開始しました。完了後にタイムスタンプが自動登録されます。"
      else
        redirect_to event_timestamps_path(@event, tab: "analysis"), alert: dispatch_result.error_message
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def timestamp_batch
      @timestamp_batch ||= EventTimestampBatch.new(event: @event)
    end

    def assign_show_state(tab: params[:tab])
      @tab = TABS.include?(tab) ? tab : TABS.first
      @matches = timestamp_batch.matches
      @timestamp_calculator = EventTimestampCalculator.new(event: @event)
      @first_match_video_timestamp_text = format_timestamp(@event.first_match_video_timestamp)
    end
  end
end
