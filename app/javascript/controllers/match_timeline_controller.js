import { Controller } from "@hotwired/stimulus"

// Rendering constants
const ICON_W     = 55   // left column (mobile suit icon)
const ROW_H      = 38   // height per player row
const HEADER_H   = 35   // height of time axis header
const TEAM_GAP   = 6    // gap between team 1 and team 2
const END_PAD    = 18   // right padding (END badge overflow area)

// 2-lane layout within each player row
// Upper lane: EXバースト system  /  Lower lane: EXオーバーリミット system
const EX_BAR_H   = 14   // EXバースト lane bar height
const EX_BAR_OFF = 3    // EXバースト lane y-offset from row top
const OL_BAR_H   = 10   // OL lane bar height
const OL_BAR_OFF = 21   // OL lane y-offset from row top (3 + 14 + 4px gap)

// EXオーバーリミット system — rendered in lower lane
const OL_CLASSES = new Set(["ov", "exbst-ov"])

// class_name → rendering style (bar events)
const CLASS_STYLES = {
  "ex":       { fill: "#C7D2FE", stroke: null },        // EXバースト発動可能域 (indigo-200)
  "exbst-f":  { fill: "#F97316", stroke: null },        // ファイティングバースト (orange)
  "exbst-s":  { fill: "#3B82F6", stroke: null },        // シューティングバースト (blue)
  "exbst-e":  { fill: "#22C55E", stroke: null },        // エクステンドバースト (green)
  "ov":       { fill: "#DDD6FE", stroke: null },        // EXオーバーリミット発動可能域 (violet-200, light fill)
  "exbst-ov": { fill: "#8B5CF6", stroke: null },        // EXオーバーリミット発動中 (brand purple)
  "com":      { fill: "url(#hatch)", stroke: "#94A3B8" }, // データ無し
}

// EXバーストクロス: rendered as row background overlay (not a lane bar)
const XB_BG_COLOR = "#EDE9FE"

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

    const groups      = data.groups      || {}
    const events      = data.events      || []
    const gameEndCs   = data.game_end_cs || 36000
    const teamInfo   = data.team_info  || {}  // group key → DB team_number (1 or 2)
    const winnerKeys = new Set(data.winner_keys || [])  // group keys belonging to winning team

    // Returns DB team number for a group key.
    // Uses server-provided team_info (name-matched) with fallback to key-name convention.
    const teamOf = key => teamInfo[key] ?? (key.startsWith("team1") ? 1 : 2)

    // Returns team color: blue for winner, red for loser.
    const teamColor = key => winnerKeys.has(key) ? "#3B82F6" : "#EF4444"

    // Use server-provided group_order (matches stats table display order = position-ascending)
    // Fall back to numeric sort of group keys when not provided
    const groupKeys = data.group_order
      ? data.group_order.filter(k => Object.prototype.hasOwnProperty.call(groups, k))
      : Object.keys(groups).sort((a, b) => {
          const parse = s => s.replace("team", "").split("-").map(Number)
          const [at, ai] = parse(a)
          const [bt, bi] = parse(b)
          return at !== bt ? at - bt : ai - bi
        })
    if (groupKeys.length === 0) return

    const containerW = Math.max(this.element.clientWidth || 700, 550)
    const chartW     = Math.max(containerW - ICON_W - END_PAD, 400)
    const scale      = chartW / gameEndCs
    const endX       = ICON_W + gameEndCs * scale

    // Y position for each group row
    const groupY = {}
    groupKeys.forEach((key, i) => {
      const gapOffset = teamOf(key) === 2 ? TEAM_GAP : 0
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
      </pattern>
      <clipPath id="chart-clip">
        <rect x="${ICON_W}" y="${HEADER_H}" width="${chartW}" height="${totalH - HEADER_H}"/>
      </clipPath>`
    svg.appendChild(defs)

    const majorInterval = gameEndCs <= 18000 ? 3000 : 6000  // 30s or 60s
    const minorInterval = 1000                               // 10s

    // 1. Background
    svg.appendChild(svgEl("rect", { x: 0, y: 0, width: totalW, height: totalH, fill: "#EEF2FF" }))

    // 2. Row backgrounds + team indicator + icon + lane divider
    groupKeys.forEach(key => {
      const y         = groupY[key]
      const iconUrl = groups[key]

      svg.appendChild(svgEl("rect", { x: 0, y, width: totalW, height: ROW_H, fill: "#FFFFFF" }))
      // 2px team color indicator on left edge
      svg.appendChild(svgEl("rect", { x: 0, y, width: 2, height: ROW_H, fill: teamColor(key) }))

      // Subtle lane divider between EX and OL lanes (chart area only)
      const divY = y + OL_BAR_OFF - 2
      svg.appendChild(svgEl("line", {
        x1: ICON_W, x2: endX,
        y1: divY, y2: divY,
        stroke: "#C7D2FE", "stroke-width": 0.5, "stroke-dasharray": "3,3",
      }))

      if (iconUrl) {
        svg.appendChild(svgEl("image", {
          href: iconUrl, x: 6, y: y + 3,
          width: ICON_W - 10, height: ROW_H - 6,
          preserveAspectRatio: "xMidYMid meet",
        }))
      }
    })

    // 3. Team separator
    const firstT2 = groupKeys.find(k => teamOf(k) === 2)
    if (firstT2) {
      const sepY = groupY[firstT2] - TEAM_GAP / 2
      svg.appendChild(svgEl("line", {
        x1: 0, x2: totalW, y1: sepY, y2: sepY,
        stroke: "#C7D2FE", "stroke-width": 1,
      }))
    }

    // 4 & 5. Grid lines + time axis — clipped to chart width, stop before END line
    const axisGroup = svgEl("g")

    for (let cs = 0; cs <= gameEndCs; cs += majorInterval) {
      axisGroup.appendChild(svgEl("line", {
        x1: ICON_W + cs * scale, x2: ICON_W + cs * scale,
        y1: HEADER_H, y2: totalH - 8,
        stroke: "#C7D2FE", "stroke-width": 1,
      }))
    }

    for (let cs = 0; cs <= gameEndCs; cs += minorInterval) {
      const x       = ICON_W + cs * scale
      const isMajor = cs % majorInterval === 0
      const tickH   = isMajor ? 8 : 4
      axisGroup.appendChild(svgEl("line", {
        x1: x, x2: x, y1: HEADER_H - tickH, y2: HEADER_H,
        stroke: isMajor ? "#6366F1" : "#C7D2FE", "stroke-width": 1,
      }))
      if (isMajor) {
        const t = svgEl("text", {
          x, y: HEADER_H - 10, "text-anchor": "middle",
          fill: "#6366F1", "font-size": 11, "font-weight": "bold",
        })
        t.textContent = fmtCs(cs)
        axisGroup.appendChild(t)
      }
    }
    svg.appendChild(axisGroup)

    // 6. Events — passes 1 & 2 inside clipped group; pass 3 (death markers) rendered after END line
    const chartGroup = svgEl("g", { "clip-path": "url(#chart-clip)" })

    // Pass 1: EXバーストクロス → full-row background overlay
    events.forEach(evt => {
      if (evt.class_name !== "xb") return
      const y = groupY[evt.group]
      if (y === undefined) return
      const x = ICON_W + evt.start_cs * scale
      const w = Math.max((evt.end_cs - evt.start_cs) * scale, 2)
      chartGroup.appendChild(svgEl("rect", { x, y, width: w, height: ROW_H, fill: XB_BG_COLOR }))
    })

    // Pass 2: Lane bars
    events.forEach(evt => {
      if (evt.class_name === "xb" || evt.is_point) return
      const y = groupY[evt.group]
      if (y === undefined) return

      const style  = CLASS_STYLES[evt.class_name] || { fill: "#6B7280", stroke: null }
      const x      = ICON_W + evt.start_cs * scale
      const w      = Math.max((evt.end_cs - evt.start_cs) * scale, 2)
      const isOL   = OL_CLASSES.has(evt.class_name)
      const barH   = isOL ? OL_BAR_H : EX_BAR_H
      const barOff = isOL ? OL_BAR_OFF : EX_BAR_OFF

      const bar = svgEl("rect", {
        x, y: y + barOff, width: w, height: barH, rx: 2,
        fill: style.fill,
      })
      if (style.stroke) {
        bar.setAttribute("stroke", style.stroke)
        bar.setAttribute("stroke-width", 1.5)
      }
      chartGroup.appendChild(bar)
    })

    svg.appendChild(chartGroup)

    // 7. END marker
    // Post-game tint — applied per row (white areas only, skips team gap and bottom padding)
    groupKeys.forEach(key => {
      svg.appendChild(svgEl("rect", {
        x: endX, y: groupY[key],
        width: totalW - endX, height: ROW_H,
        fill: "#6366F1", "fill-opacity": 0.1,
      }))
    })
    // Boundary line (full height, clearly marks game end)
    svg.appendChild(svgEl("line", {
      x1: endX, x2: endX, y1: 0, y2: totalH,
      stroke: "#6366F1", "stroke-width": 2,
    }))

    // Pass 3: Death markers — drawn after END line so ✕ appears on top; no clamp (center = exact time)
    events.forEach(evt => {
      if (!evt.is_point) return
      const y = groupY[evt.group]
      if (y === undefined) return
      const x  = Math.min(ICON_W + evt.start_cs * scale, endX)
      const cy = y + ROW_H / 2
      const s  = 5
      const arms = [[-s,-s,s,s],[s,-s,-s,s]]
      arms.forEach(([dx1, dy1, dx2, dy2]) => {
        svg.appendChild(svgEl("line", {
          x1: x+dx1, y1: cy+dy1, x2: x+dx2, y2: cy+dy2,
          stroke: "#FFFFFF", "stroke-width": 3.5, "stroke-linecap": "round",
        }))
      })
      arms.forEach(([dx1, dy1, dx2, dy2]) => {
        svg.appendChild(svgEl("line", {
          x1: x+dx1, y1: cy+dy1, x2: x+dx2, y2: cy+dy2,
          stroke: "#EF4444", "stroke-width": 2.5, "stroke-linecap": "round",
        }))
      })
    })

    // END badge — small pill centered on the END line in the header
    const badgeW = 30, badgeH = 14
    const badgeY = 0
    svg.appendChild(svgEl("rect", {
      x: endX - badgeW / 2, y: badgeY, width: badgeW, height: badgeH, rx: 4,
      fill: "#4338CA",
    }))
    const endBadge = svgEl("text", {
      x: endX, y: badgeY + badgeH / 2,
      "text-anchor": "middle", "dominant-baseline": "middle",
      fill: "#FFFFFF", "font-size": 9, "font-weight": "bold",
    })
    endBadge.textContent = "END"
    svg.appendChild(endBadge)

    this.element.innerHTML = ""
    this.element.appendChild(svg)
  }
}
