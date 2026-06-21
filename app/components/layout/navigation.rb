module Layout
  module Navigation
    def primary_items
      [
        [ "ダッシュボード", helpers.dashboard_path, helpers.current_page?(helpers.dashboard_path) || helpers.current_page?(helpers.root_path), :dashboard ],
        [ "イベント", helpers.events_path, request_path.start_with?("/events"), :events ],
        [ "ローテーション", helpers.rotations_path, request_path.start_with?("/rotations"), :rotations ],
        [ "対戦履歴", helpers.matches_path, request_path.start_with?("/matches"), :matches ],
        [ "統計", helpers.statistics_path, request_path.start_with?("/statistics"), :stats ],
        [ "機体一覧", helpers.mobile_suits_path, request_path.start_with?("/mobile_suits"), :suits ]
      ]
    end

    def admin_items
      return [] unless current_user&.is_admin?

      [
        [ "お知らせ管理", helpers.admin_announcements_path, request_path.start_with?("/admin/announcements"), :announce ],
        [ "Discord設定", helpers.admin_discord_channels_path, request_path.start_with?("/admin/discord_channels"), :discord ],
        [ "機体マスタ", helpers.admin_mobile_suits_path, request_path.start_with?("/admin/mobile_suits"), :suits ],
        [ "スタンプマスタ", helpers.admin_master_emojis_path, request_path.start_with?("/admin/master_emojis"), :emoji ],
        [ "ユーザー管理", helpers.admin_users_path, request_path.start_with?("/admin/users"), :users ]
      ]
    end

    def nav_item_classes(active)
      classes("nav-item", active && "nav-item-active")
    end

    # インラインSVGアイコン（mock のサイドバーアイコンと一致）
    NAV_ICON_PATHS = {
      dashboard: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
      events: '<rect x="3" y="4" width="18" height="17" rx="2"/><path d="M3 9h18M8 3v3M16 3v3"/>',
      rotations: '<path d="M4 4v6h6M20 20v-6h-6"/><path d="M20 9a8 8 0 0 0-14-3M4 15a8 8 0 0 0 14 3"/>',
      matches: '<path d="M4 6h16M4 12h16M4 18h16"/>',
      stats: '<path d="M5 20V10M12 20V4M19 20v-7"/>',
      suits: '<path d="M3 7l9-4 9 4-9 4-9-4zM3 7v10l9 4 9-4V7"/>',
      announce: '<path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/>',
      discord: '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>',
      emoji: '<circle cx="12" cy="12" r="9"/><path d="M8 14s1.5 2 4 2 4-2 4-2M9 9h.01M15 9h.01"/>',
      users: '<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>'
    }.freeze

    def nav_icon(key)
      paths = NAV_ICON_PATHS[key] || ""
      raw(%(<svg class="nav-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">#{paths}</svg>))
    end

    def avatar_initial(user)
      user&.nickname.to_s.first.presence || "?"
    end

    def request_path
      helpers.request.path
    end
  end
end
