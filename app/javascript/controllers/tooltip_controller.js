import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  connect() {
    this._outsideClickHandler = this._handleOutsideClick.bind(this)
    this._dismiss = this.hide.bind(this)
  }

  disconnect() {
    this._removeListeners()
  }

  show() {
    const tooltip = this.contentTarget
    tooltip.classList.remove("hidden")
    this._position()
    document.addEventListener("click", this._outsideClickHandler)
    // スクロール・リサイズで閉じる（残留・ズレ防止）
    window.addEventListener("scroll", this._dismiss, true)
    window.addEventListener("resize", this._dismiss)
  }

  hide() {
    this.contentTarget.classList.add("hidden")
    this._removeListeners()
  }

  toggle(event) {
    event.stopPropagation()
    this.contentTarget.classList.contains("hidden") ? this.show() : this.hide()
  }

  _removeListeners() {
    document.removeEventListener("click", this._outsideClickHandler)
    window.removeEventListener("scroll", this._dismiss, true)
    window.removeEventListener("resize", this._dismiss)
  }

  _position() {
    const tooltip = this.contentTarget
    const rect = this.element.getBoundingClientRect()
    const GAP = 8
    const MARGIN = 8
    tooltip.style.position = "fixed"
    tooltip.style.top = `${rect.top - GAP}px`
    tooltip.style.transform = "translateY(-100%)"
    // アイコン中央を基準に、左右が画面外へはみ出さないようクランプ
    const width = tooltip.offsetWidth
    let left = rect.left + rect.width / 2 - width / 2
    left = Math.max(MARGIN, Math.min(left, window.innerWidth - width - MARGIN))
    tooltip.style.left = `${left}px`
  }

  _handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.hide()
    }
  }
}
