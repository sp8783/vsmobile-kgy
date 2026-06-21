import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "openIcon", "closeIcon"]

  toggle(event) {
    const expanded = event.currentTarget.getAttribute("aria-expanded") === "true"
    event.currentTarget.setAttribute("aria-expanded", String(!expanded))
    this.panelTarget.classList.toggle("hidden", expanded)
    this.openIconTarget.classList.toggle("hidden", !expanded)
    this.closeIconTarget.classList.toggle("hidden", expanded)
  }
}
