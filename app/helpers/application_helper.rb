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

  # サイドバーと同じナビアイコンを view から使う（Layout::Navigation の定義を共有）
  def nav_icon_svg(key, css_class: "h-5 w-5")
    paths = Layout::Navigation::NAV_ICON_PATHS[key] || ""
    raw(%(<svg class="#{css_class}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">#{paths}</svg>))
  end

  def safe_external_url(url)
    uri = URI.parse(url.to_s)
    %w[http https].include?(uri.scheme) ? url : "#"
  rescue URI::InvalidURIError
    "#"
  end

  def cost_badge(cost)
    render Ui::CostBadgeComponent.new(cost: cost)
  end

  # ヒートマップの最大濃度（アクセント%）と、文字を白系に切り替える閾値
  HEAT_MAX = 100
  HEAT_DARK_THRESHOLD = 80

  # 0〜1 の割合 → アクセント%（0〜HEAT_MAX）
  def heat_pct(fraction)
    ([ [ fraction.to_f, 0.0 ].max, 1.0 ].min * HEAT_MAX).round
  end

  # 勝率(0〜100) → アクセント%。勝率をそのまま線形割り当て
  def winrate_heat_pct(win_rate)
    heat_pct(win_rate.to_f / 100.0)
  end

  # アクセント% からセル背景色を生成
  def heat_bg(pct)
    "color-mix(in oklab, var(--color-accent) #{pct}%, var(--color-surface-2))"
  end

  # 濃いセル（白文字に切り替えるべきか）
  def heat_dark?(pct)
    pct >= HEAT_DARK_THRESHOLD
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
      content_tag(:span, "+", class: "mx-1 text-muted"),
      cost_badge(costs[1].to_i)
    ])
  end
end
