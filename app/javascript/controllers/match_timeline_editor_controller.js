import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "chart", "error"]

  connect() {
    // Show preview for existing timeline data
    if (this.inputTarget.value.trim()) {
      this.preview()
    }
  }

  preview() {
    const raw = this.inputTarget.value.trim()

    if (!raw) {
      this.previewTarget.classList.add("hidden")
      this.errorTarget.classList.add("hidden")
      return
    }

    try {
      JSON.parse(raw)  // validation only
      this.errorTarget.classList.add("hidden")
      this.errorTarget.textContent = ""

      // Push new JSON value to the nested match-timeline controller.
      // Stimulus's Value API automatically calls jsonValueChanged() which re-renders.
      this.chartTarget.dataset.matchTimelineJsonValue = raw

      this.previewTarget.classList.remove("hidden")
    } catch (e) {
      this.errorTarget.textContent = `JSON 解析エラー: ${e.message}`
      this.errorTarget.classList.remove("hidden")
      this.previewTarget.classList.add("hidden")
    }
  }
}
