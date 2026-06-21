import { Controller } from "@hotwired/stimulus"

// お気に入り機体の画像ボタンをクリックすると、対応する select（tom-select）に即反映する
export default class extends Controller {
  static targets = ["select", "btn"]

  connect() {
    this.boundSync = this.sync.bind(this)
    if (this.hasSelectTarget) this.selectTarget.addEventListener("change", this.boundSync)
    this.sync()
  }

  disconnect() {
    if (this.hasSelectTarget) this.selectTarget.removeEventListener("change", this.boundSync)
  }

  pick(event) {
    const id = event.currentTarget.dataset.suitId
    const sel = this.selectTarget
    if (sel.tomselect) {
      sel.tomselect.setValue(id)
    } else {
      sel.value = id
      sel.dispatchEvent(new Event("change", { bubbles: true }))
    }
    this.sync()
  }

  // ドロップダウン側の選択をボタンのハイライトに反映
  sync() {
    if (!this.hasSelectTarget) return
    const val = String(this.selectTarget.value || "")
    this.btnTargets.forEach((b) => {
      b.classList.toggle("is-active", b.dataset.suitId === val)
    })
  }
}
