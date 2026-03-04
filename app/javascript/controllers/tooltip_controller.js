import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  connect() {
    this._outsideClickHandler = this._handleOutsideClick.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClickHandler)
  }

  show() {
    const tooltip = this.contentTarget
    tooltip.classList.remove("hidden")
    this._position()
    document.addEventListener("click", this._outsideClickHandler)
  }

  hide() {
    this.contentTarget.classList.add("hidden")
    document.removeEventListener("click", this._outsideClickHandler)
  }

  toggle(event) {
    event.stopPropagation()
    this.contentTarget.classList.contains("hidden") ? this.show() : this.hide()
  }

  _position() {
    const tooltip = this.contentTarget
    const rect = this.element.getBoundingClientRect()
    const GAP = 8
    tooltip.style.position = "fixed"
    tooltip.style.left = `${rect.left + rect.width / 2}px`
    tooltip.style.top = `${rect.top - GAP}px`
    tooltip.style.transform = "translate(-50%, -100%)"
  }

  _handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.hide()
    }
  }
}
