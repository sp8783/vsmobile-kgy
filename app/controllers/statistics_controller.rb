class StatisticsController < ApplicationController
  PERSONAL_TABS = %w[overview performance events event_progression mobile_suits opponent_suits partners opponents].freeze
  PERSONAL_SNAPSHOT_TABS = %w[overview events event_progression mobile_suits opponent_suits partners opponents].freeze

  before_action :authenticate_user!
  before_action :set_regular_users
  before_action :set_filters
  before_action :apply_filters

  def index
    # デフォルトは個人「総合」。ゲストは個人統計不可なので全体ランキングを既定に
    @active_tab = params[:tab] || (viewing_as_user.is_guest ? "highlights" : "overview")

    # ゲストユーザー（または管理者がゲスト視点切り替え中）は個人統計タブにアクセス不可
    if viewing_as_user.is_guest && PERSONAL_TABS.include?(@active_tab)
      redirect_to statistics_path(tab: "highlights"), alert: "ゲストユーザーには個人統計データがありません"
      return
    end

    case @active_tab
    when *PERSONAL_SNAPSHOT_TABS
      assign_view_state(StatisticsPersonalTabSnapshot.new(tab: @active_tab, filtered_matches: @filtered_matches).to_h)
    when "overall_solo", "overall_team"
      assign_view_state(StatisticsOverallSnapshot.new(filter_events: @filter_events).to_h)
    when "performance"
      assign_view_state(
        StatisticsPerformanceSnapshot.new(
          user: viewing_as_user,
          filtered_matches: @filtered_matches,
          filter_events: @filter_events,
          filter_mobile_suits: @filter_mobile_suits,
          filter_costs: @filter_costs
        ).to_h
      )
    when "highlights"
      assign_view_state(StatisticsHighlightsSnapshot.new(filter_events: @filter_events).to_h)
      assign_view_state(StatisticsOverallSnapshot.new(filter_events: @filter_events).to_h)
    end

    set_filter_options
  end

  private

  def set_regular_users
    @regular_users = User.regular_users.order(:nickname)
  end

  def viewing_as_user
    return super if current_user&.is_admin

    if params[:view_user_id].present?
      User.regular_users.find_by(id: params[:view_user_id]) || current_user
    else
      current_user
    end
  end

  def set_filters
    @filter_events = selected_ids(:events)
    @filter_mobile_suits = selected_ids(:mobile_suits)
    @filter_partners = selected_ids(:partners)
    @filter_costs = selected_ids(:costs)
  end

  def apply_filters
    @filtered_matches = StatisticsFilteredMatchPlayersQuery.new(
      user: viewing_as_user,
      filter_events: @filter_events,
      filter_mobile_suits: @filter_mobile_suits,
      filter_partners: @filter_partners,
      filter_costs: @filter_costs
    ).call
  end

  def selected_ids(param_key)
    params[param_key].present? ? params[param_key].map(&:to_i) : []
  end

  def assign_view_state(attributes)
    attributes.each do |name, value|
      instance_variable_set("@#{name}", value)
    end
  end

  def set_filter_options
    filter_options = StatisticsFilterOptions.new(
      user: viewing_as_user,
      filter_events: @filter_events
    ).to_h

    @all_events = filter_options[:all_events]
    @all_mobile_suits = filter_options[:all_mobile_suits]
    @all_partners = filter_options[:all_partners]
  end
end
