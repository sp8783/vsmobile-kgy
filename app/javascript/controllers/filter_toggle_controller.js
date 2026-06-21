import { Controller } from "@hotwired/stimulus"

// 統計フィルターの折りたたみ。モバイルは初期状態で畳む、デスクトップは開く。
export default class extends Controller {
  static targets = ["body"]
  static values = { breakpoint: { type: Number, default: 768 } }

  connect() {
    this.expanded = window.innerWidth >= this.breakpointValue
    this.render()
  }

  toggle() {
    this.expanded = !this.expanded
    this.render()
  }

  render() {
    this.bodyTarget.hidden = !this.expanded
    this.element.classList.toggle("is-open", this.expanded)
  }
}
