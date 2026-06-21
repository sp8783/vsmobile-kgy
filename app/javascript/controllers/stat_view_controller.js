import { Controller } from "@hotwired/stimulus"

// 対戦統計のカード表示／テーブル表示を切り替える
export default class extends Controller {
  static targets = ["cards", "table", "cardsBtn", "tableBtn"]

  show(event) {
    const isCards = event.currentTarget.dataset.view === "cards"
    this.cardsTarget.classList.toggle("hidden", !isCards)
    this.tableTarget.classList.toggle("hidden", isCards)
    this.cardsBtnTarget.classList.toggle("on", isCards)
    this.tableBtnTarget.classList.toggle("on", !isCards)
  }
}
