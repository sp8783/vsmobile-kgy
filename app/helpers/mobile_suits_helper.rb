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
end
