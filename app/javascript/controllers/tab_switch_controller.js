import { Controller } from "@hotwired/stimulus"

// セグメントボタンで複数パネルを切り替える（機体ランキングの指標切替など）。
// btn と panel を data-key で対応づける。
export default class extends Controller {
  static targets = ["btn", "panel"]

  select(event) {
    const key = event.currentTarget.dataset.key
    this.btnTargets.forEach((b) => b.classList.toggle("on", b.dataset.key === key))
    this.panelTargets.forEach((p) => { p.hidden = p.dataset.key !== key })
  }
}
