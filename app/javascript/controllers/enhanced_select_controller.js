import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (typeof TomSelect === "undefined" || this.element.tomselect) return

    const optgroups = this.element.dataset.hasFavorites === "true"
      ? [{ value: "favorites", label: "お気に入り機体" }, { value: "others", label: "その他の機体" }]
      : []

    this.tomSelect = new TomSelect(this.element, {
      placeholder: this.element.dataset.placeholder || "機体を検索...",
      allowEmptyOption: true,
      dropdownParent: "body",
      plugins: ["clear_button"],
      optgroupField: "optgroup",
      optgroups,
      render: {
        no_results() {
          return '<div class="no-results">該当する機体が見つかりません</div>'
        }
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
