import { Controller } from "@hotwired/stimulus"

const SUIT_FIELDS = ["team1_player1_suit", "team1_player2_suit", "team2_player1_suit", "team2_player2_suit"]

export default class extends Controller {
  static targets = ["form", "error", "deferButton", "deferModal", "missing"]

  // 入力が足りないとき、「次の試合へ進む」なら結果未入力のまま進むかを確認し、それ以外はエラーを表示する
  validate(event) {
    if (event.submitter?.dataset.skipValidation === "true") return

    const { blankPlayers, missingWinner } = this.missingFields()
    if (blankPlayers.length === 0 && !missingWinner) return

    event.preventDefault()

    if (event.submitter?.dataset.defer === "true" && this.hasDeferModalTarget) {
      const items = []
      if (blankPlayers.length > 0) items.push(`機体：${blankPlayers.join("、")}`)
      if (missingWinner) items.push("勝利チーム")
      this.missingTarget.replaceChildren(...items.map((text) => Object.assign(document.createElement("li"), { textContent: text })))
      this.deferModalTarget.hidden = false
      return
    }

    const items = []
    if (blankPlayers.length > 0) items.push(`機体（${blankPlayers.join("、")}）`)
    if (missingWinner) items.push("勝利チーム")
    this.errorTarget.textContent = `未入力：${items.join("、")}`
    this.errorTarget.hidden = false
  }

  confirmDefer() {
    this.deferModalTarget.hidden = true
    this.formTarget.requestSubmit(this.deferButtonTarget)
  }

  closeDefer() {
    this.deferModalTarget.hidden = true
  }

  // 機体が未選択のプレイヤー名と、勝利チームが未選択かどうか
  missingFields() {
    const blankPlayers = SUIT_FIELDS
      .map((name) => this.element.querySelector(`select[name="${name}"]`))
      .filter((select) => select && !select.value)
      .map((select) => select.dataset.playerName)
    const missingWinner = !this.element.querySelector('input[name="winning_team"]:checked')

    return { blankPlayers, missingWinner }
  }
}
