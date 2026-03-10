import { Controller } from "@hotwired/stimulus"

const SLOT_LABELS = ["M", "S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9", "S10", "S11"]
const MAX_SLOTS = 12

const COST_STYLES = {
  "":     { active: "bg-white shadow text-gray-900",         inactive: "text-gray-500 hover:text-gray-700" },
  "3000": { active: "bg-red-500 text-white shadow-sm",       inactive: "text-red-500 hover:bg-red-100/80" },
  "2500": { active: "bg-orange-500 text-white shadow-sm",    inactive: "text-orange-500 hover:bg-orange-100/80" },
  "2000": { active: "bg-yellow-400 text-gray-900 shadow-sm", inactive: "text-yellow-600 hover:bg-yellow-100/80" },
  "1500": { active: "bg-green-500 text-white shadow-sm",     inactive: "text-green-600 hover:bg-green-100/80" },
}
const COST_TAB_BASE = "flex items-center gap-1.5 px-3 py-1.5 rounded-lg font-semibold text-sm transition-all whitespace-nowrap"

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
    document.body.style.overflow = "hidden"
    this._resetFilters()
    this._renderAll()
  }

  close() {
    this.modalTarget.classList.add("hidden")
    document.body.style.overflow = ""
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
      const input   = document.createElement("input")
      input.type    = "hidden"
      input.name    = "mobile_suit_ids[]"
      input.value   = id
      form.appendChild(input)
    })
    form.requestSubmit()
    this.close()
  }

  // ── フィルター ────────────────────────────────────

  search(event) {
    const q = event.target.value.trim().toLowerCase()
    this.element.querySelectorAll("[data-suit-wrapper]").forEach(wrapper => {
      const nameMatch = !q || wrapper.dataset.suitName.toLowerCase().includes(q)
      const costMatch = !this._currentCost || wrapper.dataset.suitCost === this._currentCost
      wrapper.style.display = (nameMatch && costMatch) ? "" : "none"
    })
  }

  filterCost(event) {
    const cost        = event.currentTarget.dataset.cost
    this._currentCost = cost

    this.element.querySelectorAll("[data-cost-btn]").forEach(btn => {
      const isActive     = btn.dataset.cost === cost
      btn.dataset.active = isActive ? "true" : "false"
      const s            = COST_STYLES[btn.dataset.cost] || COST_STYLES[""]
      btn.className      = `${COST_TAB_BASE} ${isActive ? s.active : s.inactive}`
    })

    const q = this.hasSearchInputTarget ? this.searchInputTarget.value.trim().toLowerCase() : ""
    this.element.querySelectorAll("[data-suit-wrapper]").forEach(wrapper => {
      const nameMatch = !q || wrapper.dataset.suitName.toLowerCase().includes(q)
      const costMatch = !cost || wrapper.dataset.suitCost === cost
      wrapper.style.display = (nameMatch && costMatch) ? "" : "none"
    })
  }

  // ── プライベート ──────────────────────────────────

  _resetFilters() {
    this._currentCost = ""
    this.element.querySelectorAll("[data-suit-wrapper]").forEach(w => w.style.display = "")
    this.element.querySelectorAll("[data-cost-btn]").forEach(btn => {
      const isActive     = btn.dataset.cost === ""
      btn.dataset.active = isActive ? "true" : "false"
      const s            = COST_STYLES[btn.dataset.cost] || COST_STYLES[""]
      btn.className      = `${COST_TAB_BASE} ${isActive ? s.active : s.inactive}`
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
      const id      = parseInt(card.dataset.suitId)
      const slotIdx = this.selected.indexOf(id)
      const badge   = card.querySelector("[data-slot-badge]")

      if (slotIdx >= 0) {
        card.classList.add("ring-2", "ring-indigo-500", "border-indigo-400")
        card.classList.remove("border-gray-200", "hover:border-indigo-300")
        let overlay = card.querySelector("[data-picker-overlay]")
        if (!overlay) {
          overlay = document.createElement("div")
          overlay.dataset.pickerOverlay = ""
          overlay.className = "absolute inset-0 bg-indigo-500/8 pointer-events-none rounded-xl"
          card.appendChild(overlay)
        }
        if (badge) {
          badge.textContent = SLOT_LABELS[slotIdx]
          badge.classList.remove("hidden")
          badge.classList.add("flex")
        }
      } else {
        card.classList.remove("ring-2", "ring-indigo-500", "border-indigo-400")
        card.classList.add("border-gray-200", "hover:border-indigo-300")
        const overlay = card.querySelector("[data-picker-overlay]")
        if (overlay) overlay.remove()
        if (badge) {
          badge.classList.add("hidden")
          badge.classList.remove("flex")
        }
      }
    })
  }

  _renderTray() {
    if (this._sortable) {
      this._sortable.destroy()
      this._sortable = null
    }

    if (this.selected.length === 0) {
      this.trayTarget.innerHTML = `<p class="col-span-6 text-sm text-gray-400 italic py-4 text-center">機体をクリックして追加…</p>`
      return
    }

    const suitMap = this._buildSuitMap()
    this.trayTarget.innerHTML = this.selected.map((id, idx) => {
      const s          = suitMap[id] || {}
      const label      = SLOT_LABELS[idx]
      const isMain     = idx === 0
      const badgeColor = isMain ? "bg-indigo-600" : "bg-indigo-400"
      const img        = s.image
        ? `<img src="/mobile_suits/${s.image}" alt="${s.name || ""}" class="w-full h-full object-contain pointer-events-none p-1">`
        : `<div class="w-full h-full flex items-center justify-center text-gray-300 text-xs">?</div>`
      return `
        <div class="tray-item flex flex-col items-center gap-1.5 cursor-grab active:cursor-grabbing select-none"
             data-tray-suit-id="${id}">
          <div class="relative w-full h-12 rounded-xl overflow-hidden bg-gradient-to-b from-gray-50 to-gray-100
                      border-2 border-indigo-300 transition-all duration-150 shadow-sm">
            ${img}
            <span class="absolute top-1 left-1 px-1.5 h-5 min-w-[20px] ${badgeColor} text-white
                         text-[10px] font-bold rounded-md flex items-center justify-center
                         pointer-events-none shadow-sm">${label}</span>
            <button type="button"
                    class="delete-btn absolute top-1 right-1 w-5 h-5 bg-red-500 hover:bg-red-600 text-white
                           text-[11px] font-bold rounded-full flex items-center justify-center shadow-md
                           pointer-events-auto z-10 leading-none"
                    data-delete-suit-id="${id}">×</button>
          </div>
          <span class="text-xs text-gray-600 font-medium leading-tight text-center w-full line-clamp-2 px-0.5
                       pointer-events-none">${s.name || ""}</span>
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
        onEnd: () => {
          // DOM の順序から selected を同期
          const items = this.trayTarget.querySelectorAll("[data-tray-suit-id]")
          this.selected = Array.from(items).map(el => parseInt(el.dataset.traySuitId))
          this._updateTrayBadges()
          this._updateCards()
          this._updateCounter()
        },
      })
    }).catch(() => {
      // Sortable が使えない場合はドラッグなしで動作継続
    })
  }

  // ドラッグ後にトレイ内バッジのテキストと色だけ更新（DOM再構築なし）
  _updateTrayBadges() {
    const items = this.trayTarget.querySelectorAll("[data-tray-suit-id]")
    items.forEach((item, idx) => {
      const badge = item.querySelector("span[class*='rounded-md']")
      if (!badge) return
      badge.textContent = SLOT_LABELS[idx]
      // メインとサブで色を切り替え
      badge.classList.toggle("bg-indigo-600", idx === 0)
      badge.classList.toggle("bg-indigo-400", idx !== 0)
    })
  }

  _onTrayClick(e) {
    // 削除ボタンのクリック
    const deleteBtn = e.target.closest("[data-delete-suit-id]")
    if (deleteBtn) {
      const id  = parseInt(deleteBtn.dataset.deleteSuitId)
      this.selected = this.selected.filter(s => s !== id)
      this._renderAll()
      return
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
