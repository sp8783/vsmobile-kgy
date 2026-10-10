import { Controller } from "@hotwired/stimulus"

const WEEKDAYS = "日月火水木金土"
// タイミングを追加するときに使う日数の候補（すでにある日数は飛ばす）
const ADD_DAYS_CANDIDATES = [3, 2, 5, 14, 4, 6, 8, 9, 10, 11, 12, 13, 1, 7]

// 文字の装飾。先に見つかったものから当てはめ、中身にも装飾を重ねる
const INLINE_RULES = [
  { re: /\*\*(.+?)\*\*/, className: "dn-b" },
  { re: /__(.+?)__/, className: "dn-u" },
  { re: /\*(.+?)\*/, className: "dn-i" },
  { re: /_(.+?)_/, className: "dn-i" },
  { re: /~~(.+?)~~/, className: "dn-s" },
  { re: /\|\|(.+?)\|\|/, className: "dn-spoiler" },
  { re: /`([^`]+)`/, leaf: "code" },
  { re: /\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/, leaf: "masked" },
  { re: /@everyone|@here/, leaf: "mention" },
  { re: /https?:\/\/[^\s<]+/, leaf: "url" }
]
// 箇条書きの印（字下げの深さごと）
const BULLETS = ["•", "◦", "▪"]
const DISCORD_LINK = /^https:\/\/(?:ptb\.|canary\.)?discord(?:app)?\.com\/channels\/\d+\/\d+(\/\d+)?\/?$/

// 管理画面「Discord 投稿文」の 1 枚のカード。送るタイミングの行の追加・削除と、Discord の見た目のプレビューを担う
export default class extends Controller {
  static targets = [
    "enabled", "enabledLabel", "fields", "timings", "timing", "timingTemplate", "emptyTimings", "duplicate",
    "body", "previewTabs", "previewMessage", "previewEmpty", "previewLines", "sendAt", "schedule"
  ]

  static values = { eventName: String, heldOn: String, threadUrl: String, previewIndex: { type: Number, default: 0 } }

  connect() {
    this.refresh()
  }

  addTiming() {
    const used = this.timingValues().map((timing) => timing.days)
    const days = ADD_DAYS_CANDIDATES.find((candidate) => !used.includes(candidate)) ?? 1
    const row = this.timingTemplateTarget.content.firstElementChild.cloneNode(true)
    row.querySelector("[data-role=days]").value = String(days)
    this.timingsTarget.appendChild(row)
    this.previewIndexValue = this.timingTargets.length - 1
    this.refresh()
  }

  removeTiming(event) {
    event.currentTarget.closest("[data-discord-notice-target=timing]").remove()
    this.refresh()
  }

  // 差し込み用の文字をカーソルの位置に入れる
  insert(event) {
    const textarea = this.bodyTarget
    const token = event.currentTarget.dataset.token
    const start = textarea.selectionStart ?? textarea.value.length
    const end = textarea.selectionEnd ?? start
    textarea.setRangeText(token, start, end, "end")
    textarea.focus()
    this.refresh()
  }

  selectPreview(event) {
    this.previewIndexValue = Number(event.currentTarget.dataset.index)
    this.refresh()
  }

  refresh() {
    const enabled = this.enabledTarget.checked
    this.enabledLabelTarget.textContent = enabled ? "送る" : "送らない"
    this.fieldsTarget.classList.toggle("dn-off", !enabled)

    const timings = this.timingValues()
    timings.forEach(({ row, days }) => { row.querySelector("[data-role=when]").textContent = `{いつ} →「${this.when(days)}」` })
    if (this.hasEmptyTimingsTarget) this.emptyTimingsTarget.hidden = timings.length > 0
    if (this.hasDuplicateTarget) {
      const days = timings.map((timing) => timing.days)
      this.duplicateTarget.hidden = new Set(days).size === days.length
    }

    const index = Math.min(this.previewIndexValue, Math.max(timings.length - 1, 0))
    if (this.hasPreviewTabsTarget) this.renderTabs(timings, index)

    const current = timings[index]
    const showMessage = enabled && Boolean(current)
    this.previewMessageTarget.hidden = !showMessage
    this.previewEmptyTarget.hidden = showMessage
    this.previewEmptyTarget.textContent = enabled ? "送るタイミングがありません。" : "この投稿は送りません。"
    if (showMessage) {
      this.sendAtTarget.textContent = this.sendAt(current)
      this.renderLines(this.bodyTarget.value, current.days)
    }

    this.scheduleTarget.textContent = this.scheduleText(enabled, timings)
  }

  // private

  timingValues() {
    return this.timingTargets.map((row) => ({
      row,
      days: Number(row.querySelector("[data-role=days]").value),
      hour: Number(row.querySelector("[data-role=hour]").value)
    }))
  }

  get heldOn() {
    const [year, month, day] = this.heldOnValue.split("-").map(Number)
    return new Date(year, month - 1, day)
  }

  formatDate(date) {
    return `${date.getMonth() + 1}/${date.getDate()}(${WEEKDAYS[date.getDay()]})`
  }

  when(days) {
    if (days === 1) return "明日"
    if (days === 7) return "1週間後"
    return `${days}日後`
  }

  sendAt({ days, hour }) {
    const date = this.heldOn
    date.setDate(date.getDate() - days)
    return `${this.formatDate(date)} ${hour}:00`
  }

  scheduleText(enabled, timings) {
    if (!enabled) return "送らない設定です"
    if (timings.length === 0) return "送るタイミングがありません"

    const ordered = [...timings].sort((a, b) => b.days - a.days || a.hour - b.hour)
    return `${this.eventNameValue}（${this.formatDate(this.heldOn)} 開催）の場合: ${ordered.map((timing) => this.sendAt(timing)).join("・")} に送信`
  }

  renderTabs(timings, index) {
    this.previewTabsTarget.replaceChildren(...timings.map((timing, i) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = `dn-ptab${i === index ? " on" : ""}`
      button.setAttribute("aria-pressed", String(i === index))
      button.dataset.index = String(i)
      button.dataset.action = "discord-notice#selectPreview"
      button.textContent = `${timing.days}日前 ${timing.hour}:00`
      return button
    }))
  }

  // サーバーの DiscordNotice#message_for と同じく、値が空の差し込みを含む行は消し、差し込み用の文字を置き換える
  fill(body, days) {
    const values = {
      "{イベント名}": this.eventNameValue,
      "{開催日}": this.formatDate(this.heldOn),
      "{いつ}": this.when(days),
      "{フォーラムURL}": this.threadUrlValue
    }
    return body.split(/\r?\n/)
      .filter((line) => !Object.entries(values).some(([token, value]) => !value && line.includes(token)))
      .map((line) => Object.entries(values).reduce((text, [token, value]) => text.split(token).join(value), line))
  }

  renderLines(body, days) {
    const lines = []
    let inCode = false
    this.fill(body, days).forEach((line) => {
      if (/^```/.test(line)) { inCode = !inCode; return }
      if (inCode) { lines.push(this.lineElement("dn-codeblock", [this.span(line || " ", [])])); return }

      let className = ""
      let text = line
      let match
      if ((match = line.match(/^(#{1,3}) (.*)$/))) {
        className = `dn-h${match[1].length}`
        text = match[2]
      } else if ((match = line.match(/^-# (.*)$/))) {
        className = "dn-sub"
        text = match[1]
      } else if ((match = line.match(/^> ?(.*)$/))) {
        className = "dn-quote"
        text = match[1]
      } else if ((match = line.match(/^(\s*)[-*] (.*)$/))) {
        const level = this.listLevel(match[1])
        className = `dn-li dn-li-${level}`
        text = `${BULLETS[level]}  ${match[2]}`
      } else if ((match = line.match(/^(\s*)(\d+)\. (.*)$/))) {
        className = `dn-li dn-li-${this.listLevel(match[1])}`
        text = `${match[2]}. ${match[3]}`
      }
      const spans = this.inline(text, [])
      lines.push(this.lineElement(className, spans.length ? spans : [this.span(" ", [])]))
    })
    this.previewLinesTarget.replaceChildren(...lines)
  }

  // 行頭の空白の数から、入れ子の箇条書きの深さ（0〜2）を決める
  listLevel(indent) {
    return Math.min(Math.ceil(indent.replace(/\t/g, "  ").length / 2), BULLETS.length - 1)
  }

  inline(text, classNames) {
    let best = null
    INLINE_RULES.forEach((rule) => {
      const match = text.match(rule.re)
      if (match && (!best || match.index < best.match.index)) best = { match, rule }
    })
    if (!best) return text ? [this.span(text, classNames)] : []

    const { match, rule } = best
    const before = this.inline(text.slice(0, match.index), classNames)
    const after = this.inline(text.slice(match.index + match[0].length), classNames)
    let middle
    if (rule.leaf === "code") middle = [this.span(match[1], [...classNames, "dn-code"])]
    else if (rule.leaf === "masked") middle = this.inline(match[1], [...classNames, "dn-link"])
    else if (rule.leaf === "mention") middle = [this.span(match[0], [...classNames, "dn-mention"])]
    else if (rule.leaf === "url") middle = [this.urlSpan(match[0], classNames)]
    else middle = this.inline(match[1], [...classNames, rule.className])
    return [...before, ...middle, ...after]
  }

  // Discord のチャンネル・記事・メッセージへのリンクは、Discord では名前に置き換わって表示される
  urlSpan(url, classNames) {
    const match = url.match(DISCORD_LINK)
    if (match) return this.span(match[1] ? "# チャンネル名 › メッセージ" : "# チャンネル名", [...classNames, "dn-mention"])
    return this.span(url, [...classNames, "dn-link"])
  }

  span(text, classNames) {
    const span = document.createElement("span")
    span.textContent = text
    if (classNames.length) span.className = classNames.join(" ")
    return span
  }

  lineElement(className, children) {
    const div = document.createElement("div")
    div.className = `dn-line ${className}`.trim()
    div.replaceChildren(...children)
    return div
  }
}
