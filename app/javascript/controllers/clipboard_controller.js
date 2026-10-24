import { Controller } from "@hotwired/stimulus"

// テキストをクリップボードにコピーする（VS.モバイル連携の URL など）。コピーできない環境では選択状態にして長押しコピーを促す
export default class extends Controller {
  static targets = ["source", "button", "label"]

  async copy() {
    const text = this.sourceTarget.value ?? this.sourceTarget.textContent
    try {
      await navigator.clipboard.writeText(text)
      this.flash("コピーしました")
    } catch {
      this.sourceTarget.focus()
      this.sourceTarget.select()
      this.flash("長押しでコピーしてください")
    }
  }

  flash(text) {
    const original = this.labelTarget.dataset.label || (this.labelTarget.dataset.label = this.labelTarget.textContent)
    this.labelTarget.textContent = text
    this.buttonTarget.classList.add("copied")
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      this.labelTarget.textContent = original
      this.buttonTarget.classList.remove("copied")
    }, 1800)
  }
}
