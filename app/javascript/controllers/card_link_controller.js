import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { url: String }

  navigate(event) {
    if (!event.target.closest("a, button")) {
      Turbo.visit(this.urlValue)
    }
  }
}
