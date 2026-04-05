import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "panel", "toggleButton", "openIcon", "closeIcon"]

  connect() {
    this._keydownHandler = this._handleKeydown.bind(this)
    this._closeTimer = null
  }

  toggle() {
    this.isOpen() ? this.close() : this.open()
  }

  open() {
    if (!this.hasPanelTarget || !this.hasBackdropTarget) return

    clearTimeout(this._closeTimer)
    this.backdropTarget.classList.remove("hidden", "opacity-0")
    this.panelTarget.classList.remove("hidden", "opacity-0", "-translate-x-6")
    this._setExpanded(true)
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this._keydownHandler)
  }

  close() {
    if (!this.hasPanelTarget || !this.hasBackdropTarget) return

    this.backdropTarget.classList.add("opacity-0")
    this.panelTarget.classList.add("opacity-0", "-translate-x-6")
    this._setExpanded(false)
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this._keydownHandler)

    clearTimeout(this._closeTimer)
    this._closeTimer = window.setTimeout(() => {
      this.backdropTarget.classList.add("hidden")
      this.panelTarget.classList.add("hidden")
    }, 180)
  }

  disconnect() {
    clearTimeout(this._closeTimer)
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this._keydownHandler)
  }

  isOpen() {
    return this.hasPanelTarget && !this.panelTarget.classList.contains("hidden")
  }

  _handleKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  _setExpanded(expanded) {
    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.setAttribute("aria-expanded", expanded ? "true" : "false")
    }

    if (this.hasOpenIconTarget) this.openIconTarget.classList.toggle("hidden", expanded)
    if (this.hasCloseIconTarget) this.closeIconTarget.classList.toggle("hidden", !expanded)
  }
}
