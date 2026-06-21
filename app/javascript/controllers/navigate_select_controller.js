import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    param: String
  }

  change() {
    if (!this.element.value) return

    const url = new URL(window.location.href)
    url.searchParams.set(this.paramValue, this.element.value)
    window.location.href = url.toString()
  }
}
