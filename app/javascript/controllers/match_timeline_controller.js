import { Controller } from "@hotwired/stimulus"

const COLORS = {
  timelineEx: "rgb(199 210 254)",
  timelineF: "rgb(249 115 22)",
  timelineS: "rgb(59 130 246)",
  timelineE: "rgb(34 197 94)",
  timelineXb: "rgb(237 233 254)",
  timelineOv: "rgb(221 214 254)",
  timelineOvActive: "rgb(139 92 246)",
  accent: "rgb(43 84 255)",
  accentSoft: "rgb(238 242 255)",
  axis: "rgb(99 102 241)",
  neg: "rgb(229 56 77)",
  surface: "rgb(255 255 255)",
  muted: "rgb(107 114 128)",
  hatch: "rgb(148 163 184)",
}

const ICON_W     = 55   // left column (mobile suit icon)
const ROW_H      = 38   // height per player row
const HEADER_H   = 35   // height of time axis header
const TEAM_GAP   = 6    // gap between team 1 and team 2
const END_PAD    = 18   // right padding (END badge overflow area)

// Two lanes within each player row.
const EX_BAR_H   = 14   // EXバースト lane bar height
const EX_BAR_OFF = 3    // EXバースト lane y-offset from row top
const OL_BAR_H   = 10   // OL lane bar height
const OL_BAR_OFF = 21   // OL lane y-offset from row top (3 + 14 + 4px gap)

const OL_CLASSES = new Set(["ov", "exbst-ov"])

const CLASS_STYLES = {
  "ex":       { fill: COLORS.timelineEx, stroke: null },
  "exbst-f":  { fill: COLORS.timelineF, stroke: null },
  "exbst-s":  { fill: COLORS.timelineS, stroke: null },
  "exbst-e":  { fill: COLORS.timelineE, stroke: null },
  "ov":       { fill: COLORS.timelineOv, stroke: null },
  "exbst-ov": { fill: COLORS.timelineOvActive, stroke: null },
  "com":      { fill: "url(#hatch)", stroke: COLORS.hatch },
}

const XB_BG_COLOR = COLORS.timelineXb

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
      this.element.innerHTML = '<p class="p-2 text-xs font-bold text-neg">タイムラインデータの解析に失敗しました</p>'
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

    const teamColor = key => winnerKeys.has(key) ? COLORS.accent : COLORS.neg

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
      class: "match-timeline-svg",
    })

    const defs = svgEl("defs")
    const pattern = svgEl("pattern", {
      id: "hatch",
      patternUnits: "userSpaceOnUse",
      width: 6,
      height: 6,
      patternTransform: "rotate(45)",
    })
    pattern.appendChild(svgEl("line", {
      x1: 0, y1: 0, x2: 0, y2: 6,
      stroke: COLORS.hatch, "stroke-width": 2,
    }))
    const clipPath = svgEl("clipPath", { id: "chart-clip" })
    clipPath.appendChild(svgEl("rect", {
      x: ICON_W,
      y: HEADER_H,
      width: chartW,
      height: totalH - HEADER_H,
    }))
    defs.append(pattern, clipPath)
    svg.appendChild(defs)

    const majorInterval = gameEndCs <= 18000 ? 3000 : 6000  // 30s or 60s
    const minorInterval = 1000                               // 10s

    // 1. Background
    svg.appendChild(svgEl("rect", { x: 0, y: 0, width: totalW, height: totalH, fill: COLORS.accentSoft }))

    // 2. Row backgrounds + team indicator + icon + lane divider
    groupKeys.forEach(key => {
      const y         = groupY[key]
      const iconUrl = groups[key]

      svg.appendChild(svgEl("rect", { x: 0, y, width: totalW, height: ROW_H, fill: COLORS.surface }))
      // 2px team color indicator on left edge
      svg.appendChild(svgEl("rect", { x: 0, y, width: 2, height: ROW_H, fill: teamColor(key) }))

      // Subtle lane divider between EX and OL lanes (chart area only)
      const divY = y + OL_BAR_OFF - 2
      svg.appendChild(svgEl("line", {
        x1: ICON_W, x2: endX,
        y1: divY, y2: divY,
        stroke: COLORS.timelineEx, "stroke-width": 0.5, "stroke-dasharray": "3,3",
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
        stroke: COLORS.timelineEx, "stroke-width": 1,
      }))
    }

    // 4 & 5. Grid lines + time axis — clipped to chart width, stop before END line
    const axisGroup = svgEl("g")

    for (let cs = 0; cs <= gameEndCs; cs += majorInterval) {
      axisGroup.appendChild(svgEl("line", {
        x1: ICON_W + cs * scale, x2: ICON_W + cs * scale,
        y1: HEADER_H, y2: totalH - 8,
        stroke: COLORS.timelineEx, "stroke-width": 1,
      }))
    }

    for (let cs = 0; cs <= gameEndCs; cs += minorInterval) {
      const x       = ICON_W + cs * scale
      const isMajor = cs % majorInterval === 0
      const tickH   = isMajor ? 8 : 4
      axisGroup.appendChild(svgEl("line", {
        x1: x, x2: x, y1: HEADER_H - tickH, y2: HEADER_H,
        stroke: isMajor ? COLORS.axis : COLORS.timelineEx, "stroke-width": 1,
      }))
      if (isMajor) {
        const t = svgEl("text", {
          x, y: HEADER_H - 10, "text-anchor": "middle",
          fill: COLORS.axis, "font-size": 11, "font-weight": "bold",
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

      const style  = CLASS_STYLES[evt.class_name] || { fill: COLORS.muted, stroke: null }
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
        fill: COLORS.axis, "fill-opacity": 0.1,
      }))
    })
    // Boundary line (full height, clearly marks game end)
    svg.appendChild(svgEl("line", {
      x1: endX, x2: endX, y1: 0, y2: totalH,
      stroke: COLORS.axis, "stroke-width": 2,
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
          stroke: COLORS.surface, "stroke-width": 3.5, "stroke-linecap": "round",
        }))
      })
      arms.forEach(([dx1, dy1, dx2, dy2]) => {
        svg.appendChild(svgEl("line", {
          x1: x+dx1, y1: cy+dy1, x2: x+dx2, y2: cy+dy2,
          stroke: COLORS.neg, "stroke-width": 2.5, "stroke-linecap": "round",
        }))
      })
    })

    // END badge — small pill centered on the END line in the header
    const badgeW = 30, badgeH = 14
    const badgeY = 0
    svg.appendChild(svgEl("rect", {
      x: endX - badgeW / 2, y: badgeY, width: badgeW, height: badgeH, rx: 4,
      fill: COLORS.accent,
    }))
    const endBadge = svgEl("text", {
      x: endX, y: badgeY + badgeH / 2,
      "text-anchor": "middle", "dominant-baseline": "middle",
      fill: COLORS.surface, "font-size": 9, "font-weight": "bold",
    })
    endBadge.textContent = "END"
    svg.appendChild(endBadge)

    this.element.innerHTML = ""
    this.element.appendChild(svg)
  }
}
