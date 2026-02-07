import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tooltip", "names"]

  connect() {
    this.longPressTimer = null
    this.longPressDuration = 500 // 500ms for long press
    this.isTooltipVisible = false
    this.modal = null
    this.longPressTriggered = false
  }

  disconnect() {
    this.cancelLongPress()
    this.hideTooltip()
    this.closeModal()
  }

  // PC: マウスホバーで表示
  showTooltip(event) {
    // タッチデバイスの場合はホバーを無視（長押しで対応）
    if (this.isTouchDevice()) return

    const nicknames = this.element.dataset.nicknames
    if (!nicknames || nicknames.trim() === '') return

    if (this.hasTooltipTarget) {
      this.updateTooltipContent(nicknames)
      this.tooltipTarget.classList.remove('hidden')
      this.isTooltipVisible = true
      this.positionTooltip()
    }
  }

  // PC: マウスが離れたら非表示
  hideTooltip() {
    if (this.hasTooltipTarget) {
      this.tooltipTarget.classList.add('hidden')
      this.isTooltipVisible = false
    }
  }

  // スマホ: 長押し開始
  startLongPress(event) {
    const nicknames = this.element.dataset.nicknames
    if (!nicknames || nicknames.trim() === '') return

    // preventDefault()はtouchstartで呼ばない（clickイベントがブロックされるため）
    this.longPressTriggered = false

    this.longPressTimer = setTimeout(() => {
      this.longPressTriggered = true
      this.showModal()
    }, this.longPressDuration)
  }

  // スマホ: 長押し終了
  endLongPress(event) {
    this.cancelLongPress()
    if (this.longPressTriggered) {
      // 長押し後のclickイベント発火を防止（フォーム送信を防ぐ）
      event.preventDefault()
      this.longPressTriggered = false
    }
  }

  // スマホ: 指が動いたらキャンセル
  cancelLongPress() {
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer)
      this.longPressTimer = null
    }
  }

  // スマホ: モーダルを表示（Discord風）
  showModal() {
    const nicknames = this.element.dataset.nicknames
    if (!nicknames || nicknames.trim() === '') return

    // 既存のモーダルがあれば閉じる
    this.closeModal()

    // 軽い振動フィードバック（対応デバイスのみ）
    if (navigator.vibrate) {
      navigator.vibrate(50)
    }

    // 絵文字を取得（ボタン内の画像またはテキスト）
    const emojiElement = this.element.querySelector('.reaction-button span:first-child')
    let emojiHtml = ''
    if (emojiElement) {
      const img = emojiElement.querySelector('img')
      if (img) {
        emojiHtml = `<img src="${img.src}" alt="${img.alt}" class="w-8 h-8">`
      } else {
        emojiHtml = `<span class="text-3xl">${emojiElement.textContent}</span>`
      }
    }

    // ニックネームをリスト形式に
    const nicknameList = nicknames.split(', ').map(name =>
      `<div class="py-2 px-4 border-b border-gray-100 last:border-b-0">${this.escapeHtml(name)}</div>`
    ).join('')

    // モーダルを作成
    this.modal = document.createElement('div')
    this.modal.className = 'reaction-modal-overlay fixed inset-0 z-50 flex items-center justify-center bg-black/50'
    this.modal.innerHTML = `
      <div class="reaction-modal bg-white rounded-2xl shadow-xl mx-4 max-w-sm w-full overflow-hidden" data-modal-content>
        <div class="bg-gray-50 px-4 py-3 flex items-center gap-3 border-b border-gray-200">
          ${emojiHtml}
          <span class="text-lg font-semibold text-gray-700">リアクションしたユーザー</span>
        </div>
        <div class="max-h-64 overflow-y-auto">
          ${nicknameList}
        </div>
        <div class="px-4 py-3 border-t border-gray-200">
          <button type="button" class="w-full py-2 bg-gray-100 hover:bg-gray-200 rounded-lg text-gray-700 font-medium transition-colors" data-close-modal>
            閉じる
          </button>
        </div>
      </div>
    `

    // イベントリスナーを設定
    this.modal.addEventListener('click', (e) => {
      // モーダルの外側または閉じるボタンをクリックしたら閉じる
      if (e.target === this.modal || e.target.hasAttribute('data-close-modal')) {
        this.closeModal()
      }
    })

    // bodyに追加
    document.body.appendChild(this.modal)

    // スクロールを防止
    document.body.style.overflow = 'hidden'
  }

  // モーダルを閉じる
  closeModal() {
    if (this.modal) {
      this.modal.remove()
      this.modal = null
      document.body.style.overflow = ''
    }
  }

  // HTMLエスケープ
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  // ツールチップの内容を更新
  updateTooltipContent(nicknames) {
    if (this.hasNamesTarget) {
      this.namesTarget.textContent = nicknames
    }
  }

  // ツールチップの位置を調整（画面外にはみ出さないように）
  positionTooltip() {
    if (!this.hasTooltipTarget) return

    const tooltip = this.tooltipTarget
    if (!tooltip) return

    // インラインスタイルをクリアしてCSSクラスに任せる
    tooltip.style.left = ''
    tooltip.style.right = ''
    tooltip.style.transform = ''
  }

  // タッチデバイスかどうかを判定
  isTouchDevice() {
    return ('ontouchstart' in window) ||
           (navigator.maxTouchPoints > 0) ||
           (navigator.msMaxTouchPoints > 0)
  }
}
