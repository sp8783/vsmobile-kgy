import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { storageKey: String }

  connect() {
    const url = sessionStorage.getItem(this.storageKeyValue)
    if (url) {
      this.element.href = url
    }
  }
}
