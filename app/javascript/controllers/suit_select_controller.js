import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (typeof TomSelect === 'undefined') return
    this.tomSelect = new TomSelect(this.element, {
      placeholder: '機体を検索...',
      maxOptions: null,
      dropdownParent: 'body',
      onChange: (value) => {
        const url = new URL(window.location.href)
        url.searchParams.delete('mobile_suits[]')
        if (value) url.searchParams.set('mobile_suits[]', value)
        window.location.href = url.toString()
      }
    })
  }

  disconnect() {
    if (this.tomSelect) {
      this.tomSelect.destroy()
      this.tomSelect = null
    }
  }
}
