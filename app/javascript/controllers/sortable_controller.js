import { Controller } from "@hotwired/stimulus"

// 戦績リストのクライアントサイド並べ替え。
// ボタン式（少数キー）と セレクト＋昇降順ボタン式（多数キー）の両対応。
// data-disp-<key> があれば、並べ替えキーに応じて各行の .st-srmetric を更新。
export default class extends Controller {
  static targets = ["list", "btn", "select", "dirbtn"]

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
    const dataKey = "sort" + key.charAt(0).toUpperCase() + key.slice(1)
    const rows = Array.from(this.listTarget.children)
    rows.sort((a, b) => {
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
    if (!this.currentKey) return
    const dispKey = "disp" + this.currentKey.charAt(0).toUpperCase() + this.currentKey.slice(1)
    this.listTarget.querySelectorAll(".st-srmetric").forEach((el) => {
      const row = el.closest(".st-srow")
      const v = row && row.dataset[dispKey]
      if (v != null) el.textContent = v
    })
  }
}
