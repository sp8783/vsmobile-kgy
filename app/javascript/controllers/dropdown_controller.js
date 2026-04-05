import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.open = false
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.open = !this.open
    this.render()
  }

  hide(event) {
    if (this.element.contains(event.target)) return
    this.open = false
    this.render()
  }

  close() {
    this.open = false
    this.render()
  }

  render() {
    if (!this.hasMenuTarget) return
    this.menuTarget.classList.toggle("hidden", !this.open)
  }
}
