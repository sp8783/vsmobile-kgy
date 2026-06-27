import { Controller } from "@hotwired/stimulus"

// 戦績リストのクライアントサイド並べ替え。
// ボタン式（少数キー）と セレクト＋昇降順ボタン式（多数キー）の両対応。
// metric value が true の時は、並べ替えキーに連動して各行の右の数値(.st-srwr)と
// バー(.st-winbar)を data-val-<key> / data-bar-<key> から更新する。
export default class extends Controller {
  static targets = ["list", "btn", "select", "dirbtn"]
  static values = { metric: Boolean }

  connect() {
    if (this.hasSelectTarget) {
      this.currentKey = this.selectTarget.value
      this.currentDir = this.selectedOptionDir()
      this.updateMetric()
      this.updateDirBtn()
    }
  }

  // ボタン式：同じキー再クリックで昇降順トグル
  sort(event) {
    const btn = event.currentTarget
    const key = btn.dataset.key
    let dir = btn.dataset.dir || "desc"
    if (btn.classList.contains("is-active")) dir = dir === "desc" ? "asc" : "desc"
    btn.dataset.dir = dir
    this.btnTargets.forEach((b) => {
      const active = b === btn
      b.classList.toggle("is-active", active)
      const arrow = b.querySelector(".st-sortdir")
      if (arrow) arrow.textContent = active ? (dir === "desc" ? "▼" : "▲") : ""
    })
    this.applySort(key, dir)
  }

  // セレクト式
  sortFromSelect() {
    this.applySort(this.selectTarget.value, this.selectedOptionDir())
    this.updateDirBtn()
  }

  toggleDir() {
    this.applySort(this.currentKey, this.currentDir === "desc" ? "asc" : "desc")
    this.updateDirBtn()
  }

  selectedOptionDir() {
    const opt = this.selectTarget.selectedOptions[0]
    return (opt && opt.dataset.dir) || "desc"
  }

  updateDirBtn() {
    if (this.hasDirbtnTarget) {
      this.dirbtnTarget.textContent = this.currentDir === "desc" ? "▼ 降順" : "▲ 昇順"
    }
  }

  applySort(key, dir) {
    const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1)
    const dataKey = "sort" + cap(key)
    // 指標にデータが無い行（表示値が "—"）は昇順・降順どちらでも常に最下部へ
    const valKey = "val" + cap(key)
    const noData = (el) => el.dataset[valKey] === "—"
    const rows = Array.from(this.listTarget.children)
    rows.sort((a, b) => {
      const na = noData(a)
      const nb = noData(b)
      if (na !== nb) return na ? 1 : -1
      const an = parseFloat(a.dataset[dataKey])
      const bn = parseFloat(b.dataset[dataKey])
      let cmp
      if (!isNaN(an) && !isNaN(bn)) cmp = an - bn
      else cmp = String(a.dataset[dataKey] || "").localeCompare(String(b.dataset[dataKey] || ""), "ja")
      return dir === "desc" ? -cmp : cmp
    })
    rows.forEach((row) => this.listTarget.appendChild(row))
    this.currentKey = key
    this.currentDir = dir
    this.updateMetric()
  }

  updateMetric() {
    if (!this.metricValue || !this.currentKey) return
    const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1)
    const valKey = "val" + cap(this.currentKey)
    const barKey = "bar" + cap(this.currentKey)
    const isRate = this.currentKey === "winrate"
    this.listTarget.querySelectorAll(".st-srow").forEach((row) => {
      const val = row.dataset[valKey]
      const bar = parseFloat(row.dataset[barKey])
      const neg = isRate && row.dataset.negWinrate === "1"

      const srwr = row.querySelector(".st-srwr")
      if (srwr && val != null) {
        srwr.textContent = val
        srwr.classList.toggle("neg", neg)
      }

      const fill = row.querySelector(".st-winbar .wfill")
      if (fill && !isNaN(bar)) {
        fill.style.width = bar + "%"
        fill.classList.toggle("neg", neg)
      }

      const winbar = row.querySelector(".st-winbar")
      if (winbar) winbar.classList.toggle("show-ref", isRate)
    })
  }
}
