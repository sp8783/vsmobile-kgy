import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// ここまで引いて離すとページを読み直す（px）
const THRESHOLD = 72
// 中身を押し下げる上限（px）
const MAX_PULL = 110
// 読み直しがこの時間で終わらなければ（オフラインなど）、元に戻す
const TIMEOUT_MS = 10000

// スマホの引っ張って更新（iOS や X と同じ、中身を押し下げる形）。
// スクロールする範囲はトップバーの下の中身（scroller）だけなので、トップバーは引いても動かない。
// 中身の一番上で下に引くと、引いた分だけ中身が下にずれ、トップバーとのすき間にマーク（indicator）が見える。
// THRESHOLD 以上引いて離すとマークが回りながらページを読み直す（Turbo でその場を再表示）。
// スクロールして一番上に着いたあと、指を離さずに引き続けた場合も引っ張りとして扱う
export default class extends Controller {
  static targets = ["scroller", "indicator"]

  connect() {
    this.tracking = false
    this.lastY = 0
    this.startY = null
    this.distance = 0
    this.refreshing = false
    this.onStart = this.start.bind(this)
    this.onMove = this.move.bind(this)
    this.onEnd = this.end.bind(this)
    // touchmove はページ全体のゴムのような伸びを止めるため preventDefault する（passive: false）
    this.scrollerTarget.addEventListener("touchstart", this.onStart, { passive: true })
    this.scrollerTarget.addEventListener("touchmove", this.onMove, { passive: false })
    this.scrollerTarget.addEventListener("touchend", this.onEnd)
    this.scrollerTarget.addEventListener("touchcancel", this.onEnd)
  }

  disconnect() {
    this.scrollerTarget.removeEventListener("touchstart", this.onStart)
    this.scrollerTarget.removeEventListener("touchmove", this.onMove)
    this.scrollerTarget.removeEventListener("touchend", this.onEnd)
    this.scrollerTarget.removeEventListener("touchcancel", this.onEnd)
    clearTimeout(this.timer)
  }

  // private

  start(event) {
    if (this.refreshing || event.touches.length !== 1) return
    this.tracking = true
    this.lastY = event.touches[0].clientY
    this.startY = null
  }

  move(event) {
    if (!this.tracking || this.refreshing) return

    const y = event.touches[0].clientY
    const atTop = this.scrollerTarget.scrollTop <= 0
    // 一番上にいて下に動かし始めた時点から引っ張りを測る（触れ始めが一番上でなくてもよい）
    if (this.startY === null && atTop && y > this.lastY) this.startY = this.lastY
    this.lastY = y
    if (this.startY === null) return

    const dy = y - this.startY
    if (dy <= 0 || !atTop) {
      // 上に戻した・中身がスクロールし始めた → 引っ張りをやめる
      this.startY = null
      this.release(0)
      return
    }

    event.preventDefault()
    this.distance = Math.min(dy * 0.55, MAX_PULL)
    this.scrollerTarget.classList.add("pulling")
    this.indicatorTarget.classList.add("pulling")
    this.render(this.distance, Math.round(this.distance * 2.5))
  }

  end() {
    if (!this.tracking) return

    this.tracking = false
    const pulled = this.startY !== null
    this.startY = null
    if (pulled && this.distance >= THRESHOLD) {
      this.refresh()
    } else if (pulled) {
      this.release(0)
    }
  }

  // 中身を distance だけ押し下げ、すき間の真ん中にマークを出す
  render(distance, angle) {
    const indicator = this.indicatorTarget
    this.scrollerTarget.style.transform = distance ? `translateY(${distance}px)` : ""
    indicator.style.opacity = String(Math.min(distance / THRESHOLD, 1))
    indicator.style.transform = `translateY(${Math.max(distance - indicator.offsetHeight, 0) / 2}px) rotate(${angle}deg)`
  }

  // 離したあと、アニメーションつきで distance の位置に戻す
  release(distance) {
    this.distance = distance
    this.scrollerTarget.classList.remove("pulling")
    this.indicatorTarget.classList.remove("pulling")
    this.render(distance, 0)
    if (distance === 0) this.indicatorTarget.style.transform = ""
  }

  refresh() {
    this.refreshing = true
    this.indicatorTarget.classList.add("refreshing")
    this.release(THRESHOLD)
    this.timer = setTimeout(() => this.reset(), TIMEOUT_MS)
    // 読み直しが終わるとページが描き直され、このコントローラも作り直される（中身とマークは初期状態に戻る）
    Turbo.visit(window.location.href, { action: "replace" })
  }

  reset() {
    clearTimeout(this.timer)
    this.tracking = false
    this.startY = null
    this.refreshing = false
    this.indicatorTarget.classList.remove("refreshing")
    this.release(0)
  }
}
