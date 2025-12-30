import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (typeof TomSelect !== 'undefined') {
      this.tomSelect = new TomSelect(this.element, {
        placeholder: this.element.getAttribute("data-placeholder") || "選択してください",
        allowEmptyOption: true,
        plugins: ['clear_button'],
        maxOptions: null
      })
    } else {
      console.error("TomSelect is not loaded")
    }
  }

  disconnect() {
    if (this.tomSelect) {
      this.tomSelect.destroy()
    }
  }
}
