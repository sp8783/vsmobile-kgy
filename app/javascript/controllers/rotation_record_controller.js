import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "title",
    "matchIndex",
    "submitText",
    "cancelButton",
    "skipButton",
    "nextButton"
  ]

  static values = {
    updateUrl: String
  }

  edit(event) {
    event.preventDefault()
    event.stopPropagation()

    const data = event.currentTarget.dataset
    this.titleTarget.textContent = `試合結果を編集（第${Number(data.matchIndex) + 1}試合）`
    this.formTarget.action = this.updateUrlValue
    this.matchIndexTarget.value = data.matchIndex
    this.submitTextTarget.textContent = "更新"

    this.setSelectValue("team1_player1_suit", data.suit1)
    this.setSelectValue("team1_player2_suit", data.suit2)
    this.setSelectValue("team2_player1_suit", data.suit3)
    this.setSelectValue("team2_player2_suit", data.suit4)

    const winner = this.element.querySelector(`input[name="winning_team"][value="${data.winningTeam}"]`)
    if (winner) winner.checked = true

    if (this.hasSkipButtonTarget) this.skipButtonTarget.classList.add("hidden")
    if (this.hasNextButtonTarget) this.nextButtonTarget.classList.add("hidden")
    this.cancelButtonTarget.classList.remove("hidden")
    this.element.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  cancel() {
    window.location.reload()
  }

  validate(event) {
    if (event.submitter?.dataset.skipValidation === "true") return

    const names = ["team1_player1_suit", "team1_player2_suit", "team2_player1_suit", "team2_player2_suit"]
    const missingSuit = names.some((name) => !this.element.querySelector(`[name="${name}"]`)?.value)
    const missingWinner = !this.element.querySelector('input[name="winning_team"]:checked')

    if (missingSuit) {
      event.preventDefault()
      window.alert("すべてのプレイヤーの機体を選択してください")
      return
    }

    if (missingWinner) {
      event.preventDefault()
      window.alert("勝利チームを選択してください")
    }
  }

  setSelectValue(name, value) {
    const select = this.element.querySelector(`[name="${name}"]`)
    if (!select || !value) return

    if (select.tomselect) {
      select.tomselect.setValue(String(value))
    } else {
      select.value = String(value)
    }
  }
}
