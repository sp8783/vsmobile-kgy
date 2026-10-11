import { Controller } from "@hotwired/stimulus"

// 先頭のまとまり（data-lead-group）ごとの見出し
const OPTGROUPS = {
  recent: [{ value: "recent", label: "最近使った機体" }, { value: "others", label: "その他の機体" }]
}

export default class extends Controller {
  connect() {
    if (typeof TomSelect === "undefined" || this.element.tomselect) return

    const optgroups = OPTGROUPS[this.element.dataset.leadGroup] ?? []

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
