module MobileSuitsHelper
  COST_STYLES = {
    3000 => { badge: "cost-badge cost-badge-3000", tab_active: "bg-cost-3000 text-on-accent shadow-card", tab_inactive: "text-cost-3000 hover:bg-cost-3000-bg", bar: "bg-cost-3000" },
    2500 => { badge: "cost-badge cost-badge-2500", tab_active: "bg-cost-2500 text-on-accent shadow-card", tab_inactive: "text-cost-2500 hover:bg-cost-2500-bg", bar: "bg-cost-2500" },
    2000 => { badge: "cost-badge cost-badge-2000", tab_active: "bg-cost-2000 text-ink shadow-card", tab_inactive: "text-cost-2000 hover:bg-cost-2000-bg", bar: "bg-cost-2000" },
    1500 => { badge: "cost-badge cost-badge-1500", tab_active: "bg-cost-1500 text-on-accent shadow-card", tab_inactive: "text-cost-1500 hover:bg-cost-1500-bg", bar: "bg-cost-1500" }
  }.freeze

  def cost_badge_classes(cost)
    COST_STYLES.dig(cost, :badge) || "cost-badge"
  end

  def cost_bar_classes(cost)
    COST_STYLES.dig(cost, :bar) || "bg-muted"
  end

  # "フルアーマー：7強化型：8" のような連結スペック文字列を
  # [{label: "フルアーマー", value: "7"}, {label: "強化型", value: "8"}] に分解する。
  # ラベルなし単純値（"8", "A"）は [{label: nil, value: "8"}] を返す。
  def parse_spec_field(str)
    return [] if str.blank?
    return [ { label: nil, value: str } ] unless str.include?("：")

    parts  = str.split("：")
    result = [ { label: parts[0], value: nil } ]

    parts[1..].each do |part|
      # 値は数字列 or 大文字1文字（ランクS/A/B/C/D）。
      # 値の直後に続く文字が次の形態名の先頭。
      if (m = part.match(/\A(\d+)(.+)\z/))
        result.last[:value] = m[1]
        result << { label: m[2], value: nil }
      elsif (m = part.match(/\A([A-Z])(.+)\z/))
        result.last[:value] = m[1]
        result << { label: m[2], value: nil }
      else
        result.last[:value] = part
      end
    end

    result
  end
end
