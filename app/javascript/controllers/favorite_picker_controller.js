import { Controller } from "@hotwired/stimulus"

const MAX_SLOTS = 12

export default class extends Controller {
  static targets = ["modal", "form", "tray", "countBadge", "saveBtn", "searchInput"]
  static values  = { initial: Array }

  connect() {
    this.selected     = [...this.initialValue]
    this._currentCost = ""
    this._sortable    = null
    this._trayHandler = this._onTrayClick.bind(this)
    this.trayTarget.addEventListener("click", this._trayHandler)
  }

  disconnect() {
    this.trayTarget.removeEventListener("click", this._trayHandler)
    if (this._sortable) this._sortable.destroy()
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
    } else if (this.selected.length < MAX_SLOTS) {
      this.selected.push(id)
    }
    this._renderAll()
  }

  clearAll() {
    this.selected = []
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

    this.element.querySelectorAll("[data-cost-btn]").forEach(btn => {
      const isActive     = btn.dataset.cost === cost
      btn.dataset.active = isActive ? "true" : "false"
      btn.className      = this._costTabClass(btn.dataset.cost, isActive)
    })

    const q = this.hasSearchInputTarget ? this.searchInputTarget.value.trim().toLowerCase() : ""
    this._applyFilter(q, cost)
  }

  _applyFilter(q, cost) {
    this.element.querySelectorAll("[data-suit-wrapper]").forEach(wrapper => {
      const nameMatch = !q || wrapper.dataset.suitName.toLowerCase().includes(q)
      const costMatch = !cost || wrapper.dataset.suitCost === cost
      wrapper.classList.toggle("hidden", !(nameMatch && costMatch))
    })
  }

  _costTabClass(cost, isActive) {
    const base = cost ? `pk-costtab c${cost}` : "pk-costtab"
    return isActive ? `${base} on` : base
  }

  // ── プライベート ──────────────────────────────────

  _resetFilters() {
    this._currentCost = ""
    this.element.querySelectorAll("[data-suit-wrapper]").forEach(w => w.classList.remove("hidden"))
    this.element.querySelectorAll("[data-cost-btn]").forEach(btn => {
      const isActive     = btn.dataset.cost === ""
      btn.dataset.active = isActive ? "true" : "false"
      btn.className      = this._costTabClass(btn.dataset.cost, isActive)
    })
    if (this.hasSearchInputTarget) this.searchInputTarget.value = ""
  }

  _renderAll() {
    this._updateCards()
    this._renderTray()
    this._updateCounter()
  }

  _updateCards() {
    this.element.querySelectorAll("[data-suit-id]").forEach(card => {
      const id = parseInt(card.dataset.suitId)
      card.classList.toggle("is-sel", this.selected.indexOf(id) >= 0)
    })
  }

  _renderTray() {
    if (this._sortable) {
      this._sortable.destroy()
      this._sortable = null
    }

    if (this.selected.length === 0) {
      this.trayTarget.innerHTML = `<div class="pk-trayempty">機体をクリックして追加…</div>`
      return
    }

    const suitMap = this._buildSuitMap()
    this.trayTarget.innerHTML = this.selected.map(id => {
      const s   = suitMap[id] || {}
      const img = s.image
        ? `<img src="/mobile_suits/${s.image}" alt="${s.name || ""}">`
        : `<span class="ph">?</span>`
      return `
        <div class="pk-trayitem" data-tray-suit-id="${id}">
          <button type="button" class="tx" data-delete-suit-id="${id}" aria-label="削除">×</button>
          <div class="tt">${img}</div>
          <div class="tname">${s.name || ""}</div>
        </div>`
    }).join("")

    // Sortable を dynamic import で初期化（読み込み失敗でも他機能は壊れない）
    import("sortablejs").then(({ default: Sortable }) => {
      if (this._sortable) this._sortable.destroy()
      this._sortable = new Sortable(this.trayTarget, {
        animation:   180,
        easing:      "cubic-bezier(0.25, 1, 0.5, 1)",
        ghostClass:  "tray-ghost",
        chosenClass: "tray-chosen",
        dragClass:   "tray-dragging",
        filter:      ".tx",
        onEnd: () => {
          const items = this.trayTarget.querySelectorAll("[data-tray-suit-id]")
          this.selected = Array.from(items).map(el => parseInt(el.dataset.traySuitId))
          this._updateCounter()
        },
      })
    }).catch(() => {
      // Sortable が使えない場合はドラッグなしで動作継続
    })
  }

  _onTrayClick(e) {
    const deleteBtn = e.target.closest("[data-delete-suit-id]")
    if (deleteBtn) {
      const id = parseInt(deleteBtn.dataset.deleteSuitId)
      this.selected = this.selected.filter(s => s !== id)
      this._renderAll()
    }
  }

  _updateCounter() {
    this.countBadgeTarget.textContent = `${this.selected.length} / ${MAX_SLOTS}`
    this.saveBtnTarget.textContent =
      this.selected.length > 0 ? `保存（${this.selected.length}機体）` : "保存"
  }

  _buildSuitMap() {
    const map = {}
    this.element.querySelectorAll("[data-suit-id]").forEach(card => {
      map[parseInt(card.dataset.suitId)] = {
        name:  card.dataset.suitName  || "",
        image: card.dataset.suitImage || "",
      }
    })
    return map
  }
}
