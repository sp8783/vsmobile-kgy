import { Controller } from "@hotwired/stimulus"

// 試合カードの一括選択（管理者用）。
// 「選択」トグルで選択モードに入ると、カードのどこをタップしても選択ON/OFFできる。
// 通常時はカードタップで詳細へ遷移する（mh-cardlink）。
export default class extends Controller {
  static targets = ["toggle", "actions", "all", "item", "count", "card"]

  connect() {
    this.selecting = false
  }

  // 選択モードの ON/OFF
  toggleMode() {
    this.selecting = !this.selecting
    this.element.classList.toggle("mh-selecting", this.selecting)
    if (this.hasToggleTarget) this.toggleTarget.classList.toggle("on", this.selecting)
    if (this.hasActionsTarget) this.actionsTarget.hidden = !this.selecting
    if (!this.selecting) this.clear()
  }

  clear() {
    this.itemTargets.forEach((item) => (item.checked = false))
    this.cardTargets.forEach((card) => card.classList.remove("is-selected"))
    this.update()
  }

  // 選択モード中、カード本体のタップで選択を切り替える
  cardClick(event) {
    if (!this.selecting) return
    // カード内のリンク/ボタン/リアクションはそのまま動かす（選択トグルしない）
    if (event.target.closest("a:not(.mh-cardlink), button, input, label, .mh-rbar")) return

    event.preventDefault()
    const card = event.currentTarget
    const box = card.querySelector('input[type="checkbox"]')
    if (!box) return

    box.checked = !box.checked
    card.classList.toggle("is-selected", box.checked)
    this.update()
  }

  toggleAll() {
    this.itemTargets.forEach((item, index) => {
      item.checked = this.allTarget.checked
      this.cardTargets[index]?.classList.toggle("is-selected", item.checked)
    })
    this.update()
  }

  update() {
    const checked = this.itemTargets.filter((item) => item.checked).length
    if (this.hasCountTarget) this.countTarget.textContent = `${checked}件選択中`
    if (this.hasAllTarget) {
      this.allTarget.checked = checked > 0 && checked === this.itemTargets.length
    }
  }
}
