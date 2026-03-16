import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    clearCost: { type: Boolean, default: false }
  }

  connect() {
    if (typeof TomSelect === 'undefined') return
    const optgroups = this.element.dataset.hasFavorites === 'true'
      ? [{ value: 'favorites', label: '★ お気に入り機体' }, { value: 'others', label: '── その他の機体 ──' }]
      : []
    this.tomSelect = new TomSelect(this.element, {
      placeholder: '機体を検索...',
      maxOptions: null,
      dropdownParent: 'body',
      optgroupField: 'optgroup',
      optgroups: optgroups,
      onChange: (value) => {
        const url = new URL(window.location.href)
        url.searchParams.delete('mobile_suits[]')
        url.searchParams.delete('my_mobile_suits')
        if (this.clearCostValue) url.searchParams.delete('costs[]')
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
