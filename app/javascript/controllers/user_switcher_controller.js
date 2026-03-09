import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown"]

  connect() {
    this._outsideClickHandler = this._onOutsideClick.bind(this)
  }

  toggle() {
    const dropdown = this.dropdownTarget
    const isHidden = dropdown.classList.contains("hidden")
    if (isHidden) {
      dropdown.classList.remove("hidden")
      document.addEventListener("click", this._outsideClickHandler)
    } else {
      this._close()
    }
  }

  switchView(event) {
    const userId = event.currentTarget.dataset.userId
    this._submitSwitchForm(userId)
  }

  clearView() {
    this._submitSwitchForm("clear")
  }

  _close() {
    this.dropdownTarget.classList.add("hidden")
    document.removeEventListener("click", this._outsideClickHandler)
  }

  _onOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this._close()
    }
  }

  _submitSwitchForm(userId) {
    const form = document.createElement("form")
    form.method = "POST"
    form.action = userId === "clear"
      ? "/admin/users/clear_view"
      : `/admin/users/${userId}/switch_view`

    const token = document.querySelector('meta[name="csrf-token"]').content
    const csrfInput = document.createElement("input")
    csrfInput.type = "hidden"
    csrfInput.name = "authenticity_token"
    csrfInput.value = token

    form.appendChild(csrfInput)
    document.body.appendChild(form)
    form.submit()
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClickHandler)
  }
}
