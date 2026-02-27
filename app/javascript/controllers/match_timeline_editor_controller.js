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
      const parsed = JSON.parse(raw)
      this.errorTarget.classList.add("hidden")
      this.errorTarget.textContent = ""

      // フルワークフロー JSON の場合は timeline_raw を抽出し、winner_keys を付加してプレビューに渡す
      const timelineRaw = parsed.timeline_raw || parsed
      let winnerKeys = []
      if (parsed.team_a && parsed.team_b) {
        const winnerPrefix = parsed.team_a.result === "win" ? "team1-" : "team2-"
        winnerKeys = Object.keys(timelineRaw.groups || {}).filter(k => k.startsWith(winnerPrefix))
      }
      const previewData = { ...timelineRaw, winner_keys: winnerKeys }

      // Push new JSON value to the nested match-timeline controller.
      // Stimulus's Value API automatically calls jsonValueChanged() which re-renders.
      this.chartTarget.dataset.matchTimelineJsonValue = JSON.stringify(previewData)

      this.previewTarget.classList.remove("hidden")
    } catch (e) {
      this.errorTarget.textContent = `JSON 解析エラー: ${e.message}`
      this.errorTarget.classList.remove("hidden")
      this.previewTarget.classList.add("hidden")
    }
  }
}
