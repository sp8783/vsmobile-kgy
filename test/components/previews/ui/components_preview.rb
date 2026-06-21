class Ui::ComponentsPreview < ViewComponent::Preview
  def card
    render Ui::CardComponent.new(title: "カードタイトル", subtitle: "補足テキスト") do
      "カード本文"
    end
  end

  def button
    render Ui::ButtonComponent.new(label: "保存", href: "#", variant: :primary)
  end

  def stat
    render Ui::StatComponent.new(label: "勝率", value: "62.5", suffix: "%", tone: :accent, meta: "全体 #1")
  end

  def cost_badge
    render Ui::CostBadgeComponent.new(cost: 3000)
  end
end
