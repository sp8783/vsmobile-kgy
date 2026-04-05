module ApplicationHelper
  MARKDOWN_RENDERER = Redcarpet::Markdown.new(
    Redcarpet::Render::HTML.new(hard_wrap: true, safe_links_only: true),
    autolink: true,
    tables: true,
    fenced_code_blocks: true,
    strikethrough: true,
    no_intra_emphasis: true
  )

  def render_markdown(text)
    return "" if text.blank?
    sanitize(
      MARKDOWN_RENDERER.render(text),
      tags: %w[p br strong em a ul ol li h1 h2 h3 h4 h5 blockquote code pre s del table thead tbody tr th td hr],
      attributes: %w[href]
    )
  end


  def cost_badge(cost)
    style = case cost.to_i
    when 3000
      "background-color: #FEE2E2; color: #991B1B;" # 赤
    when 2500
      "background-color: #FFEDD5; color: #C2410C;" # オレンジ
    when 2000
      "background-color: #FEF9C3; color: #A16207;" # 黄
    when 1500
      "background-color: #DCFCE7; color: #166534;" # 緑
    else
      "background-color: #F3F4F6; color: #1F2937;" # グレー
    end

    content_tag(:span, cost, class: "px-2 inline-flex text-xs leading-5 font-semibold rounded-full", style: style)
  end

  # centiseconds を "M:SS" 形式の文字列に変換する
  def format_survival_cs(cs)
    return nil unless cs
    total_sec = cs / 100
    "#{total_sec / 60}:#{format('%02d', total_sec % 60)}"
  end

  # お気に入り機体を先頭にした <option> タグ群を返す
  # お気に入りがある場合は favorites / others の2グループに分けて TomSelect に渡す
  def mobile_suit_options_with_favorites(suits, user, selected_ids = [])
    selected_ids = Array(selected_ids)
    fav_ids = user&.user_favorite_suits&.order(:slot)&.pluck(:mobile_suit_id) || []

    favorites = suits.select { |s| fav_ids.include?(s.id) }.sort_by { |s| fav_ids.index(s.id) }
    others    = suits.reject { |s| fav_ids.include?(s.id) }

    if favorites.any?
      safe_join(favorites.map { |s|
        content_tag(:option, "#{s.name} (#{s.cost})", value: s.id,
                    data: { optgroup: "favorites" },
                    selected: selected_ids.include?(s.id))
      }) + safe_join(others.map { |s|
        content_tag(:option, "#{s.name} (#{s.cost})", value: s.id,
                    data: { optgroup: "others" },
                    selected: selected_ids.include?(s.id))
      })
    else
      safe_join(others.map { |s|
        content_tag(:option, "#{s.name} (#{s.cost})", value: s.id,
                    selected: selected_ids.include?(s.id))
      })
    end
  end

  # コスト帯の組み合わせ（例："3000+2500"）を2つのバッジで表示
  def cost_combo_badges(cost_combo)
    costs = cost_combo.split("+").map(&:strip)
    safe_join([
      cost_badge(costs[0].to_i),
      content_tag(:span, "+", class: "mx-1 text-gray-500"),
      cost_badge(costs[1].to_i)
    ])
  end

  def app_primary_navigation_items
    [
      { label: "ダッシュボード", path: dashboard_path, active: current_page?(dashboard_path) || current_page?(root_path) },
      { label: "イベント", path: events_path, active: current_page?(events_path) },
      { label: "ローテーション", path: rotations_path, active: current_page?(rotations_path) },
      { label: "対戦履歴", path: matches_path, active: current_page?(matches_path) },
      { label: "統計", path: statistics_path, active: current_page?(statistics_path) },
      { label: "機体一覧", path: mobile_suits_path, active: current_page?(mobile_suits_path) }
    ]
  end

  def app_admin_navigation_items
    return [] unless current_user&.is_admin?

    [
      { label: "お知らせ管理", path: admin_announcements_path, active: current_page?(admin_announcements_path) },
      { label: "Discord設定", path: admin_discord_channels_path, active: current_page?(admin_discord_channels_path) },
      { label: "機体マスタ", path: admin_mobile_suits_path, active: current_page?(admin_mobile_suits_path) },
      { label: "スタンプマスタ", path: admin_master_emojis_path, active: current_page?(admin_master_emojis_path) },
      { label: "ユーザー管理", path: admin_users_path, active: current_page?(admin_users_path) }
    ]
  end

  def app_account_navigation_items
    items = []
    items << { label: "マイページ", path: my_page_path, active: current_page?(my_page_path) } unless current_user&.is_guest?
    items << { label: "設定", path: edit_profile_path, active: current_page?(edit_profile_path) } unless current_user&.username == "guest"
    items
  end

  def app_nav_link_classes(active: false, compact: false, accent: nil)
    class_names(
      "app-nav-link",
      ("app-nav-link--compact" if compact),
      ("is-active" if active),
      ("app-nav-link--#{accent}" if accent.present?)
    )
  end

  def user_avatar_initial(user)
    user&.nickname.to_s.strip.first&.upcase.presence || "?"
  end

  def flash_banner_tone(type)
    case type.to_s
    when "notice"
      :info
    when "success"
      :success
    when "alert", "error"
      :danger
    when "warning"
      :warning
    else
      :neutral
    end
  end

  def flash_banner_classes(type)
    class_names("flash-banner", "flash-banner--#{flash_banner_tone(type)}")
  end

  def flash_banner_icon_classes(type)
    class_names("flash-banner__icon", "flash-banner__icon--#{flash_banner_tone(type)}")
  end

  def flash_banner_title(type)
    case flash_banner_tone(type)
    when :success
      "完了"
    when :danger
      "注意"
    when :warning
      "確認"
    when :info
      "お知らせ"
    else
      "案内"
    end
  end

  def app_notice_classes(tone = :info)
    class_names("app-notice", "app-notice--#{tone.to_sym}")
  end

  def app_notice_icon_classes(tone = :info)
    class_names("app-notice__icon", "app-notice__icon--#{tone.to_sym}")
  end

  def safe_external_url(url)
    return nil if url.blank?

    parsed = URI.parse(url)
    return nil unless parsed.is_a?(URI::HTTP) && parsed.host.present?

    parsed.to_s
  rescue URI::InvalidURIError
    nil
  end

  def app_button_classes(variant: :primary, size: :md, full_width: false)
    variant_class = case variant.to_sym
    when :primary
      "ui-button-primary"
    when :secondary
      "ui-button-secondary"
    when :neutral
      "ui-button-neutral"
    when :success
      "ui-button-success"
    when :danger
      "ui-button-danger"
    else
      "ui-button-primary"
    end

    class_names(
      variant_class,
      ("ui-button--sm" if size.to_sym == :sm),
      ("w-full" if full_width)
    )
  end
end
