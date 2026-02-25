import { Controller } from "@hotwired/stimulus"

// Rendering constants
const ICON_W    = 55   // left column (mobile suit icon)
const ROW_H     = 38   // height per player row
const HEADER_H  = 35   // height of time axis header
const TEAM_GAP  = 6    // gap between team 1 and team 2
const BAR_H     = 20   // event bar height
const BAR_Y_OFF = (ROW_H - BAR_H) / 2  // vertical centering offset for bars
const END_PAD   = 32   // right padding (END label area)

// class_name → rendering style
const CLASS_STYLES = {
  "ex":       { fill: "#9CA3AF", stroke: null },        // EXバースト発動可能域
  "exbst-f":  { fill: "#F97316", stroke: null },        // ファイティングバースト
  "exbst-s":  { fill: "#3B82F6", stroke: null },        // シューティングバースト
  "exbst-e":  { fill: "#22C55E", stroke: null },        // エクステンドバースト
  "ov":       { fill: "none",    stroke: "#D1FAE5" },   // EXオーバーリミット発動可能域 (outline)
  "exbst-ov": { fill: "#F1F5F9", stroke: null },        // EXオーバーリミット発動中
  "xb":       { fill: "#374151", stroke: null },        // EXバーストクロス
  "com":      { fill: "url(#hatch)", stroke: "#6B7280" }, // データ無し
}

// Convert centiseconds to "M:SS" display string
function fmtCs(cs) {
  const totalSec = Math.floor(cs / 100)
  const m = Math.floor(totalSec / 60)
  const s = totalSec % 60
  return `${m}:${String(s).padStart(2, "0")}`
}

function svgEl(tag, attrs = {}, ns = "http://www.w3.org/2000/svg") {
  const el = document.createElementNS(ns, tag)
  for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v)
  return el
}

export default class extends Controller {
  static values = { json: String }

  connect() { this.render() }
  jsonValueChanged() { this.render() }

  render() {
    const raw = this.jsonValue
    if (!raw) return

    let data
    try { data = JSON.parse(raw) } catch {
      this.element.innerHTML = '<p class="text-red-400 text-xs p-2">タイムラインデータの解析に失敗しました</p>'
      return
    }

    const groups   = data.groups   || {}
    const events   = data.events   || []
    const gameEndCs = data.game_end_cs || 36000

    // Sort group keys: team1-1, team1-2, team2-1, team2-2
    const groupKeys = Object.keys(groups).sort((a, b) => {
      const parse = s => s.replace("team", "").split("-").map(Number)
      const [at, ai] = parse(a)
      const [bt, bi] = parse(b)
      return at !== bt ? at - bt : ai - bi
    })
    if (groupKeys.length === 0) return

    const containerW = Math.max(this.element.clientWidth || 700, 550)
    const chartW     = Math.max(containerW - ICON_W - END_PAD, 400)
    const scale      = chartW / gameEndCs

    // Y position for each group row
    const groupY = {}
    groupKeys.forEach((key, i) => {
      const gapOffset = key.startsWith("team2") ? TEAM_GAP : 0
      groupY[key] = HEADER_H + i * ROW_H + gapOffset
    })
    const totalH = HEADER_H + groupKeys.length * ROW_H + TEAM_GAP + 12
    const totalW = ICON_W + chartW + END_PAD

    const NS = "http://www.w3.org/2000/svg"
    const svg = svgEl("svg", {
      xmlns: NS,
      width: "100%",
      viewBox: `0 0 ${totalW} ${totalH}`,
      style: `min-width: 550px; display: block; font-family: sans-serif;`,
    })

    // Defs: hatch pattern
    const defs = svgEl("defs")
    defs.innerHTML = `
      <pattern id="hatch" patternUnits="userSpaceOnUse" width="6" height="6" patternTransform="rotate(45)">
        <line x1="0" y1="0" x2="0" y2="6" stroke="#888" stroke-width="2"/>
      </pattern>`
    svg.appendChild(defs)

    // Background
    svg.appendChild(svgEl("rect", { x: 0, y: 0, width: totalW, height: totalH, fill: "#111827" }))

    // Major/minor tick interval
    const majorInterval = gameEndCs <= 18000 ? 3000 : 6000  // 30s or 60s
    const minorInterval = 1000                               // 10s

    // Vertical grid lines at major ticks
    for (let cs = 0; cs <= gameEndCs; cs += majorInterval) {
      svg.appendChild(svgEl("line", {
        x1: ICON_W + cs * scale, x2: ICON_W + cs * scale,
        y1: HEADER_H, y2: totalH - 8,
        stroke: "#1F2937", "stroke-width": 1,
      }))
    }

    // Time axis ticks and labels
    for (let cs = 0; cs <= gameEndCs; cs += minorInterval) {
      const x      = ICON_W + cs * scale
      const isMajor = cs % majorInterval === 0
      const tickH  = isMajor ? 8 : 4
      svg.appendChild(svgEl("line", {
        x1: x, x2: x, y1: HEADER_H - tickH, y2: HEADER_H,
        stroke: isMajor ? "#9CA3AF" : "#4B5563", "stroke-width": 1,
      }))
      if (isMajor) {
        const t = svgEl("text", {
          x, y: HEADER_H - 10, "text-anchor": "middle",
          fill: "#9CA3AF", "font-size": 9,
        })
        t.textContent = fmtCs(cs)
        svg.appendChild(t)
      }
    }

    // Player rows: background + icon
    groupKeys.forEach(key => {
      const y       = groupY[key]
      const iconUrl = groups[key]
      const rowFill = key.startsWith("team1") ? "#1A2332" : "#1A2A22"

      svg.appendChild(svgEl("rect", { x: 0, y, width: totalW, height: ROW_H, fill: rowFill }))

      if (iconUrl) {
        svg.appendChild(svgEl("image", {
          href: iconUrl, x: 4, y: y + 3,
          width: ICON_W - 8, height: ROW_H - 6,
          preserveAspectRatio: "xMidYMid meet",
        }))
      }
    })

    // Team separator
    const firstT2 = groupKeys.find(k => k.startsWith("team2"))
    if (firstT2) {
      const sepY = groupY[firstT2] - TEAM_GAP / 2
      svg.appendChild(svgEl("line", {
        x1: 0, x2: totalW, y1: sepY, y2: sepY,
        stroke: "#374151", "stroke-width": 1,
      }))
    }

    // Events
    events.forEach(evt => {
      const y = groupY[evt.group]
      if (y === undefined) return

      if (evt.is_point) {
        // Death: red X mark
        const x  = ICON_W + evt.start_cs * scale
        const cy = y + ROW_H / 2
        const s  = 5
        for (const [dx1, dy1, dx2, dy2] of [[-s,-s,s,s],[s,-s,-s,s]]) {
          svg.appendChild(svgEl("line", {
            x1: x + dx1, y1: cy + dy1, x2: x + dx2, y2: cy + dy2,
            stroke: "#EF4444", "stroke-width": 2.5, "stroke-linecap": "round",
          }))
        }
        return
      }

      // Bar
      const style = CLASS_STYLES[evt.class_name] || { fill: "#6B7280", stroke: null }
      const x = ICON_W + evt.start_cs * scale
      const w = Math.max((evt.end_cs - evt.start_cs) * scale, 2)

      const bar = svgEl("rect", {
        x, y: y + BAR_Y_OFF, width: w, height: BAR_H, rx: 3,
        fill: style.fill,
      })
      if (style.stroke) {
        bar.setAttribute("stroke", style.stroke)
        bar.setAttribute("stroke-width", 1.5)
      }
      svg.appendChild(bar)

      // Diamond marker for exbst-ov (OL active)
      if (evt.class_name === "exbst-ov" && w >= 10) {
        const cx = x + w / 2
        const cy = y + ROW_H / 2
        const s  = 5
        const diamond = svgEl("polygon", {
          points: `${cx},${cy - s} ${cx + s},${cy} ${cx},${cy + s} ${cx - s},${cy}`,
          fill: "#111827",
        })
        svg.appendChild(diamond)
      }
    })

    // END marker
    const endX = ICON_W + gameEndCs * scale
    svg.appendChild(svgEl("line", {
      x1: endX, x2: endX, y1: HEADER_H, y2: totalH - 4,
      stroke: "#D1D5DB", "stroke-width": 1.5, "stroke-dasharray": "4,3",
    }))
    const endLabel = svgEl("text", {
      x: endX + 3, y: HEADER_H + 12,
      fill: "#D1D5DB", "font-size": 9,
    })
    endLabel.textContent = "END"
    svg.appendChild(endLabel)

    this.element.innerHTML = ""
    this.element.appendChild(svg)
  }
}
