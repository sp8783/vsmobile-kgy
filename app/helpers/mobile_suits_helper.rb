module MobileSuitsHelper
  COST_STYLES = {
    3000 => { badge: "bg-red-100 text-red-700",    tab_active: "bg-red-500 text-white shadow-sm",       tab_inactive: "text-red-500 hover:bg-red-100/80",     bar: "bg-red-400" },
    2500 => { badge: "bg-orange-100 text-orange-700", tab_active: "bg-orange-500 text-white shadow-sm", tab_inactive: "text-orange-500 hover:bg-orange-100/80", bar: "bg-orange-400" },
    2000 => { badge: "bg-yellow-100 text-yellow-700", tab_active: "bg-yellow-400 text-gray-900 shadow-sm", tab_inactive: "text-yellow-600 hover:bg-yellow-100/80", bar: "bg-yellow-400" },
    1500 => { badge: "bg-green-100 text-green-700",  tab_active: "bg-green-500 text-white shadow-sm",   tab_inactive: "text-green-600 hover:bg-green-100/80",    bar: "bg-green-400" }
  }.freeze

  def cost_badge_classes(cost)
    COST_STYLES.dig(cost, :badge) || "bg-gray-100 text-gray-700"
  end

  def cost_bar_classes(cost)
    COST_STYLES.dig(cost, :bar) || "bg-gray-400"
  end

  def safe_external_url(url)
    uri = URI.parse(url.to_s)
    %w[http https].include?(uri.scheme) ? url : "#"
  rescue URI::InvalidURIError
    "#"
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
