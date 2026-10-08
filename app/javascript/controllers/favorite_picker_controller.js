import { Controller } from "@hotwired/stimulus"

// 「選択中」タブで絞り込むときのキー（コスト別タブの data-cost と区別する）
const SELECTED = "selected"

export default class extends Controller {
  static targets = ["modal", "form", "countBadge", "saveBtn", "searchInput", "selectedCount", "selectedHint"]
  static values  = { initial: Array, max: Number }

  connect() {
    this.selected     = [...this.initialValue]
    this._currentCost = ""
    this._snapshot    = null
  }

  // ── 開閉 ──────────────────────────────────────────

  open() {
    this.selected = [...this.initialValue]
    this.modalTarget.classList.remove("hidden")
    document.body.classList.add("modal-open")
    this._resetFilters()
    this._renderAll()
  }

  close() {
    this.modalTarget.classList.add("hidden")
    document.body.classList.remove("modal-open")
  }

  // ── 機体選択トグル ────────────────────────────────

  toggleSuit(event) {
    const card = event.currentTarget
    const id   = parseInt(card.dataset.suitId)
    const idx  = this.selected.indexOf(id)

    if (idx >= 0) {
      this.selected.splice(idx, 1)
    } else if (this.selected.length < this.maxValue) {
      this.selected.push(id)
    }
    this._renderAll()
  }

  // ── 保存 ──────────────────────────────────────────

  save() {
    const form = this.formTarget
    form.querySelectorAll("input[name='mobile_suit_ids[]']").forEach(el => el.remove())
    this.selected.forEach(id => {
      const input = document.createElement("input")
      input.type  = "hidden"
      input.name  = "mobile_suit_ids[]"
      input.value = id
      form.appendChild(input)
    })
    form.requestSubmit()
    this.close()
  }

  // ── フィルター ────────────────────────────────────

  search(event) {
    const q = event.target.value.trim().toLowerCase()
    this._applyFilter(q, this._currentCost)
  }

  filterCost(event) {
    const cost        = event.currentTarget.dataset.cost
    this._currentCost = cost
    // 「選択中」は開いた時点の選択を固定して表示し、外した機体も再タップで戻せるよう一覧に残す
    this._snapshot    = cost === SELECTED ? [...this.selected] : null

    this.element.querySelectorAll("[data-cost-btn]").forEach(btn => {
      const isActive     = btn.dataset.cost === cost
      btn.dataset.active = isActive ? "true" : "false"
      btn.className      = this._costTabClass(btn.dataset.cost, isActive)
    })
    if (this.hasSelectedHintTarget) this.selectedHintTarget.hidden = cost !== SELECTED

    const q = this.hasSearchInputTarget ? this.searchInputTarget.value.trim().toLowerCase() : ""
    this._applyFilter(q, cost)
  }

  _applyFilter(q, cost) {
    this.element.querySelectorAll("[data-suit-wrapper]").forEach(wrapper => {
      const id        = parseInt(wrapper.dataset.suitId)
      const nameMatch = !q || wrapper.dataset.suitName.toLowerCase().includes(q)
      let costMatch   = !cost || wrapper.dataset.suitCost === cost
      if (cost === SELECTED) costMatch = this._snapshot.includes(id)

      wrapper.classList.toggle("hidden", !(nameMatch && costMatch))
      // 「選択中」では選んだ順（M, S1, …）に並べる
      wrapper.style.order = cost === SELECTED ? String(this._snapshot.indexOf(id)) : ""
    })
  }

  _costTabClass(cost, isActive) {
    let base = "pk-costtab"
    if (cost === SELECTED) base = "pk-costtab sel"
    else if (cost) base = `pk-costtab c${cost}`
    return isActive ? `${base} on` : base
  }

  // ── プライベート ──────────────────────────────────

  _resetFilters() {
    this._currentCost = ""
    this._snapshot    = null
    this.element.querySelectorAll("[data-suit-wrapper]").forEach(w => {
      w.classList.remove("hidden")
      w.style.order = ""
    })
    this.element.querySelectorAll("[data-cost-btn]").forEach(btn => {
      const isActive     = btn.dataset.cost === ""
      btn.dataset.active = isActive ? "true" : "false"
      btn.className      = this._costTabClass(btn.dataset.cost, isActive)
    })
    if (this.hasSearchInputTarget) this.searchInputTarget.value = ""
    if (this.hasSelectedHintTarget) this.selectedHintTarget.hidden = true
  }

  _renderAll() {
    this._updateCards()
    this._updateCounter()
  }

  _updateCards() {
    this.element.querySelectorAll("[data-suit-id].pk-cell").forEach(card => {
      const idx   = this.selected.indexOf(parseInt(card.dataset.suitId))
      const label = card.querySelector("[data-slot-label]")
      card.classList.toggle("is-sel", idx >= 0)
      if (label) {
        label.textContent = idx < 0 ? "" : (idx === 0 ? "M" : `S${idx}`)
        label.classList.toggle("main", idx === 0)
      }
    })
  }

  _updateCounter() {
    const count = this.selected.length
    this.countBadgeTarget.textContent = `${count} / ${this.maxValue}`
    this.saveBtnTarget.textContent    = count > 0 ? `保存する（${count}機体）` : "保存する"
    if (this.hasSelectedCountTarget) this.selectedCountTarget.textContent = count
  }
}
