import { Controller } from "@hotwired/stimulus"

// マイページのお気に入り機体の並び替えモード。
// ドラッグで個別に移動し、「コスト順」「使用回数順」でまとめて並べ替えて、保存時に並び順を一括送信する
export default class extends Controller {
  static targets = ["viewActions", "editActions", "sortBar", "sortButton", "list", "grid", "form"]

  connect() {
    this._sortable      = null
    this._originalOrder = []
  }

  disconnect() {
    this._destroySortable()
  }

  start() {
    this._originalOrder = this._tiles().map(tile => tile.dataset.suitId)
    this._toggle(true)
    this._markSortButton(null)

    // Sortable を dynamic import で初期化（読み込み失敗でも表示や保存は壊れない）
    import("sortablejs").then(({ default: Sortable }) => {
      this._destroySortable()
      this._sortable = new Sortable(this.listTarget, {
        animation:        180,
        easing:           "cubic-bezier(0.25, 1, 0.5, 1)",
        // タッチでは少し長押ししてから掴む（素早いスワイプはページのスクロールに使う）
        delay:            150,
        delayOnTouchOnly: true,
        ghostClass:       "tray-ghost",
        chosenClass:      "tray-chosen",
        dragClass:        "tray-dragging",
        onEnd: () => {
          this._markSortButton(null)
          this._refreshLabels()
        },
      })
    }).catch(() => {})
  }

  cancel() {
    const tilesById = new Map(this._tiles().map(tile => [tile.dataset.suitId, tile]))
    this._originalOrder.forEach(id => this.listTarget.appendChild(tilesById.get(id)))
    this._refreshLabels()
    this._destroySortable()
    this._toggle(false)
  }

  // コスト順（高い順）・使用回数順（多い順）。同じ値の機体は今の並びを保つ
  sort(event) {
    const key   = event.currentTarget.dataset.sortKey
    const tiles = this._tiles()
    const value = tile => Number(key === "cost" ? tile.dataset.cost : tile.dataset.usage)

    tiles
      .map((tile, index) => ({ tile, index }))
      .sort((a, b) => (value(b.tile) - value(a.tile)) || (a.index - b.index))
      .forEach(({ tile }) => this.listTarget.appendChild(tile))

    this._markSortButton(key)
    this._refreshLabels()
  }

  save() {
    const form = this.formTarget
    form.querySelectorAll("input[name='mobile_suit_ids[]']").forEach(el => el.remove())
    this._tiles().forEach(tile => {
      const input = document.createElement("input")
      input.type  = "hidden"
      input.name  = "mobile_suit_ids[]"
      input.value = tile.dataset.suitId
      form.appendChild(input)
    })
    form.requestSubmit()
  }

  _tiles() {
    return Array.from(this.listTarget.querySelectorAll("[data-suit-id]"))
  }

  _toggle(editing) {
    this.viewActionsTarget.hidden = editing
    this.editActionsTarget.hidden = !editing
    this.sortBarTarget.hidden     = !editing
    this.listTarget.hidden        = !editing
    this.gridTarget.hidden        = editing
  }

  _markSortButton(key) {
    this.sortButtonTargets.forEach(button => {
      button.classList.toggle("is-on", button.dataset.sortKey === key)
    })
  }

  _refreshLabels() {
    this._tiles().forEach((tile, index) => {
      const label = tile.querySelector("[data-slot-label]")
      label.textContent = index === 0 ? "M" : `S${index}`
      label.classList.toggle("slot-badge-main", index === 0)
      label.classList.toggle("slot-badge-sub", index !== 0)
    })
  }

  _destroySortable() {
    if (this._sortable) {
      this._sortable.destroy()
      this._sortable = null
    }
  }
}
