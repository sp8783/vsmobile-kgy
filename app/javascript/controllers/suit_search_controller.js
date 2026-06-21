import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "card", "count", "countNumber", "empty", "tab"]

  connect() {
    this.apply()
  }

  apply() {
    const query = this.inputTarget.value.trim()
    const normalized = query.toLowerCase()
    let visible = 0

    this.cardTargets.forEach((card) => {
      const show = normalized === "" || card.dataset.name.toLowerCase().includes(normalized)
      card.classList.toggle("hidden", !show)
      if (show) visible += 1
    })

    this.countNumberTarget.textContent = visible
    this.countTarget.classList.toggle("hidden", query === "")
    this.emptyTarget.classList.toggle("hidden", visible > 0 || query === "")
    this.updateTabs(query)
  }

  updateTabs(query) {
    this.tabTargets.forEach((tab) => {
      const url = new URL(tab.dataset.baseUrl, window.location.origin)
      if (query) {
        url.searchParams.set("q", query)
      } else {
        url.searchParams.delete("q")
      }
      tab.href = `${url.pathname}${url.search}`
    })
  }
}
