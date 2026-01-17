module ApplicationHelper
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

  # コスト帯の組み合わせ（例："3000+2500"）を2つのバッジで表示
  def cost_combo_badges(cost_combo)
    costs = cost_combo.split("+").map(&:strip)
    safe_join([
      cost_badge(costs[0].to_i),
      content_tag(:span, "+", class: "mx-1 text-gray-500"),
      cost_badge(costs[1].to_i)
    ])
  end
end
