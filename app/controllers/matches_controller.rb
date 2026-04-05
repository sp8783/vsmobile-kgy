class MatchesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin, except: [ :index, :show ]
  before_action :set_event, only: [ :new, :create ]
  before_action :set_match, only: [ :show, :edit, :update, :destroy ]
  before_action :load_form_options, only: [ :new, :edit ]

  def index
    filter_state = MatchesFilterState.new(params: params)
    assign_view_state(filter_state.to_h)

    @matches = MatchesFilteredQuery.new(
      filter_state: filter_state,
      viewing_as_user: viewing_as_user
    ).call
    @matches = @matches.page(params[:page]).per(@per_page)
    @emojis = MasterEmoji.active.ordered
    @latest_event = Event.order(held_on: :desc).first
    @my_favorite_match_ids = favorite_match_ids_for(@matches)

    assign_view_state(MatchesFilterOptions.new(filter_events: @filter_events).to_h)
  end

  def show
    @is_favorited = viewing_as_user ? @match.favorite_matches.exists?(user: viewing_as_user) : false
  end

  def new
    @match = @event.matches.build(played_at: Time.current)
    4.times { |i| @match.match_players.build(position: i + 1) }
  end

  def create
    @match = @event.matches.build(match_params)
    @match.played_at = Time.current

    if @match.save
      redirect_to @event, notice: "対戦記録を登録しました。"
    else
      load_form_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @match.update(match_params)
      redirect_to @match, notice: "対戦記録を更新しました。"
    else
      load_form_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    result = MatchDeletionWorkflow.new(matches: @match).call
    redirect_after_destroy(result)
  end

  def bulk_destroy
    match_ids = params[:match_ids] || []

    if match_ids.empty?
      redirect_to matches_path, alert: "削除する試合を選択してください。"
      return
    end

    result = MatchDeletionWorkflow.new(matches: Match.includes(:event).where(id: match_ids)).call

    if result.success?
      redirect_to matches_path, notice: "#{result.deleted_count}件の対戦記録を削除しました。"
    else
      redirect_to matches_path, alert: "削除に失敗しました: #{result.error_message}"
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_match
    @match = Match.includes(:event, :match_timeline, match_players: [ :user, :mobile_suit ]).find(params[:id])
  end

  def load_form_options
    @users = User.regular_users.order(:nickname)
    @mobile_suits = MobileSuit.catalog_order
  end

  def assign_view_state(attributes)
    attributes.each do |name, value|
      instance_variable_set("@#{name}", value)
    end
  end

  def favorite_match_ids_for(matches)
    return Set.new unless viewing_as_user

    FavoriteMatch.where(user_id: viewing_as_user.id, match_id: matches.map(&:id)).pluck(:match_id).to_set
  end

  def match_params
    params.require(:match).permit(:winning_team, :played_at, :video_timestamp_text, match_players_attributes: [ :id, :user_id, :mobile_suit_id, :team_number, :position ])
  end

  def redirect_after_destroy(result)
    if result.success?
      if result.rotation
        redirect_to rotation_path(result.rotation), notice: "対戦記録を削除しました。"
      else
        redirect_to event_path(result.event), notice: "対戦記録を削除しました。"
      end
    elsif result.rotation
      redirect_to rotation_path(result.rotation), alert: "削除に失敗しました: #{result.error_message}"
    else
      redirect_to event_path(result.event), alert: "削除に失敗しました: #{result.error_message}"
    end
  end
end
