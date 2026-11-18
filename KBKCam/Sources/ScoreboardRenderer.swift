import UIKit

/// Draws the scoreboard, team logos, clock and sponsor logos on a transparent full-frame image
/// (port of the Android renderer: STACKED and BAR layouts, 8 styles).
final class ScoreboardRenderer {
    var logo1: UIImage?, logo2: UIImage?   // sponsors
    var logoA: UIImage?, logoB: UIImage?   // teams

    private struct Theme {
        var bg = UIColor(hex: 0xE6101820), fg = UIColor.white, dim = UIColor(hex: 0xFF8394A0)
        var ptBg = UIColor(hex: 0xFF12A183), ptFg = UIColor.white
        var stroke: UIColor? = nil, centerBg = UIColor(hex: 0xFF0B1116), line = UIColor(hex: 0x22FFFFFF)
        var radius: CGFloat = 10
        var teamRows = false, glow = false, textShadow = false, noBackground = false
    }

    private func theme(_ style: String) -> Theme {
        var t = Theme()
        switch style {
        case "LIGHT":
            t.bg = UIColor(hex: 0xF5FFFFFF); t.fg = UIColor(hex: 0xFF101820); t.dim = UIColor(hex: 0xFF8A949C)
            t.ptBg = UIColor(hex: 0xFF101820); t.centerBg = UIColor(hex: 0xFF101820); t.line = UIColor(hex: 0x18000000)
        case "TEAM", "BAR_TEAM":
            t.teamRows = true; t.dim = UIColor(hex: 0xCCFFFFFF); t.ptBg = .white; t.ptFg = UIColor(hex: 0xFF101820)
            t.centerBg = UIColor(hex: 0xFF101820)
        case "GLASS":
            t.bg = UIColor(hex: 0x66101820); t.stroke = UIColor(hex: 0x66FFFFFF); t.dim = UIColor(hex: 0xDDFFFFFF)
            t.ptBg = UIColor(hex: 0x40FFFFFF); t.centerBg = UIColor(hex: 0x33FFFFFF); t.radius = 18; t.textShadow = true
        case "NEON":
            t.bg = UIColor(hex: 0xF2050A0E); t.stroke = UIColor(hex: 0xFF00E5FF); t.glow = true; t.dim = UIColor(hex: 0xFF5F7B88)
            t.ptBg = .clear; t.ptFg = UIColor(hex: 0xFF00E5FF); t.centerBg = .black; t.line = UIColor(hex: 0x5500E5FF); t.radius = 8
        case "MINIMAL":
            t.noBackground = true; t.textShadow = true; t.dim = UIColor(hex: 0xE6FFFFFF); t.ptBg = .clear
            t.ptFg = UIColor(hex: 0xFFD7F205); t.centerBg = .clear; t.line = .clear
        default: break
        }
        return t
    }

    func render(width W: Int, height H: Int, engine e: ScoreEngine, settings p: Settings) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let size = CGSize(width: W, height: H)
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let c = ctx.cgContext
            let u = CGFloat(H) / 720 * CGFloat(p.sizePct) / 100
            let margin = 22 * CGFloat(H) / 720
            let t = theme(p.style)
            if p.showScoreboard {
                if p.style.hasPrefix("BAR") { drawBar(c, size, u, margin, e, p, t) } else { drawStacked(c, size, u, margin, e, p, t) }
            }
            if p.showLogos { drawSponsors(size, u, margin, p) }
        }
    }

    // MARK: stacked (two rows)
    private func drawStacked(_ c: CGContext, _ S: CGSize, _ u: CGFloat, _ margin: CGFloat, _ e: ScoreEngine, _ p: Settings, _ t: Theme) {
        let kind = e.rules.sport.kind
        let cs = CGFloat(p.clockScale) / 100
        let rowH = 48 * u, strip = 7 * u, cellW = 42 * u, ptW = 68 * u
        let serveW = serveVisible(e, p) ? 20 * u : 6 * u
        let logoW = teamLogosVisible(p) ? rowH : 0
        let nameFont = UIFont.boldSystemFont(ofSize: 24 * u)
        var nameW = max(width(p.nameA, nameFont), width(p.nameB, nameFont)) + 22 * u
        nameW = max(110 * u, min(nameW, 320 * u))

        var setCols = 0
        if p.showSets {
            if kind == .racket { setCols = e.s.sets.count + (e.s.superTb ? 0 : 1) }
            else if kind == .rally { setCols = e.s.sets.count }
        }

        let clock = clockVisible(e, p) ? ScoreEngine.formatClock(p.shownClock(e)) : ""
        let info = infoText(e, p)
        let clockFont = UIFont.monospacedDigitSystemFont(ofSize: 26 * cs * u, weight: .heavy)
        let infoFont = UIFont.boldSystemFont(ofSize: 16 * u)
        var footH: CGFloat = 0
        if !clock.isEmpty || !info.isEmpty { footH = clock.isEmpty ? 30 * u : (30 * cs + 12) * u }
        let clockW = clock.isEmpty ? 0 : width(clock, clockFont)
        let infoW = info.isEmpty ? 0 : width(info, infoFont)

        var boxW = strip + serveW + logoW + nameW + CGFloat(setCols) * cellW + ptW
        boxW = max(boxW, strip + 14 * u + clockW + (infoW > 0 ? 18 * u + infoW : 0) + 14 * u)
        let boxH = rowH * 2 + footH
        let box = place(boxW, boxH, S, margin, p.position)
        let x = box.minX, y = box.minY

        drawBackground(c, box, u, t)
        c.saveGState()
        UIBezierPath(roundedRect: box, cornerRadius: t.radius * u).addClip()

        for i in 0..<2 {
            let ry = y + CGFloat(i) * rowH
            let teamColor = p.uiColor(i)
            if t.teamRows { fill(c, CGRect(x: x, y: ry, width: boxW - ptW, height: rowH), teamColor.withAlphaComponent(0.88)) }
            fill(c, CGRect(x: x, y: ry, width: strip, height: rowH), teamColor)
            var cx = x + strip
            if serveVisible(e, p) && e.s.server == i {
                UIColor(hex: 0xFFD7F205).setFill()
                UIBezierPath(ovalIn: CGRect(x: cx + serveW / 2 - 5.5 * u, y: ry + rowH / 2 - 5.5 * u, width: 11 * u, height: 11 * u)).fill()
            }
            cx += serveW
            if logoW > 0 {
                drawFit(i == 0 ? logoA : logoB, CGRect(x: cx + 4 * u, y: ry + 5 * u, width: logoW - 8 * u, height: rowH - 10 * u))
                cx += logoW
            }
            var nameColor = t.teamRows ? textOn(teamColor) : t.fg
            if e.s.finished && e.s.winner != i { nameColor = t.teamRows ? UIColor(white: 1, alpha: 0.6) : t.dim }
            drawText(ellipsize(i == 0 ? p.nameA : p.nameB, nameFont, nameW - 14 * u), nameFont, nameColor, x: cx + 6 * u, cy: ry + rowH / 2, align: .left, t: t, glow: false)
            cx += nameW

            var shown = 0
            for (k, set) in e.s.sets.enumerated() where shown < setCols {
                let col = set[i] > set[1 - i] ? (t.teamRows ? textOn(teamColor) : t.fg) : (t.teamRows ? UIColor(white: 1, alpha: 0.6) : t.dim)
                drawText("\(set[i])", .boldSystemFont(ofSize: 22 * u), col, x: cx + CGFloat(k) * cellW + cellW / 2, cy: ry + rowH / 2, align: .center, t: t, glow: false)
                shown += 1
            }
            if kind == .racket && shown < setCols {
                drawText("\(e.s.games[i])", .boldSystemFont(ofSize: 24 * u), t.teamRows ? textOn(teamColor) : t.fg,
                         x: cx + CGFloat(shown) * cellW + cellW / 2, cy: ry + rowH / 2, align: .center, t: t, glow: false)
            }
            let px = x + boxW - ptW
            fill(c, CGRect(x: px, y: ry, width: ptW, height: rowH), t.ptBg)
            drawText(e.pointLabel(i), .boldSystemFont(ofSize: 28 * u), t.ptFg, x: px + ptW / 2, cy: ry + rowH / 2, align: .center, t: t, glow: t.glow)
        }
        fill(c, CGRect(x: x, y: y + rowH - 0.75 * u, width: boxW, height: 1.5 * u), t.line)

        if footH > 0 {
            let fy = y + rowH * 2
            fill(c, CGRect(x: x, y: fy, width: boxW, height: footH), t.centerBg.withAlphaComponent(min(0.7, t.centerBg.alpha)))
            if !clock.isEmpty {
                drawText(clock, clockFont, clockColor(e, p, t), x: x + strip + 10 * u, cy: fy + footH / 2, align: .left, t: t, glow: t.glow)
            }
            if !info.isEmpty {
                drawText(info, infoFont, t.dim, x: clock.isEmpty ? x + strip + 10 * u : x + boxW - 12 * u, cy: fy + footH / 2,
                         align: clock.isEmpty ? .left : .right, t: t, glow: false)
            }
        }
        c.restoreGState()
        drawStroke(box, u, t)
    }

    // MARK: bar (one line)
    private func drawBar(_ c: CGContext, _ S: CGSize, _ u: CGFloat, _ margin: CGFloat, _ e: ScoreEngine, _ p: Settings, _ t: Theme) {
        let kind = e.rules.sport.kind
        let cs = CGFloat(p.clockScale) / 100
        let h = max(56 * u, (30 * cs + 18) * u)
        let pad = 12 * u, ptW = 66 * u
        let logoW = teamLogosVisible(p) ? h - 10 * u : 0
        let serveW = serveVisible(e, p) ? 16 * u : 0
        let nameFont = UIFont.boldSystemFont(ofSize: 24 * u)
        var nameW = max(width(p.nameA, nameFont), width(p.nameB, nameFont)) + 16 * u
        nameW = max(80 * u, min(nameW, 280 * u))

        let finished = p.showSets && kind != .goals ? e.s.sets.count : 0
        let setCell = 24 * u
        let gameCell: CGFloat = kind == .racket && p.showSets && !e.s.superTb ? 38 * u : 0
        let setsW = CGFloat(finished) * setCell + gameCell

        let clock = clockVisible(e, p) ? ScoreEngine.formatClock(p.shownClock(e)) : ""
        let info = infoText(e, p)
        let isClock = !clock.isEmpty
        let center = isClock ? clock : (info.isEmpty ? "–" : info)
        let centerFont: UIFont = isClock ? .monospacedDigitSystemFont(ofSize: 28 * cs * u, weight: .heavy) : .boldSystemFont(ofSize: 18 * u)
        let centerW = max(isClock ? 104 * u : 70 * u, width(center, centerFont) + 28 * u)

        let sideW = pad + logoW + (logoW > 0 ? 8 * u : 0) + serveW + nameW + setsW + ptW
        let boxW = sideW * 2 + centerW
        var box = place(boxW, h, S, margin, p.position)
        let left = box.minX, right = box.maxX, top = box.minY

        drawBackground(c, box, u, t)
        c.saveGState()
        UIBezierPath(roundedRect: box, cornerRadius: t.radius * u).addClip()

        func side(_ i: Int, _ lx: CGFloat, _ w: CGFloat, _ y: CGFloat = 0, _ hh: CGFloat? = nil) -> CGRect {
            let hgt = hh ?? h
            return i == 0 ? CGRect(x: left + lx, y: top + y, width: w, height: hgt)
                          : CGRect(x: right - lx - w, y: top + y, width: w, height: hgt)
        }

        for i in 0..<2 {
            let teamColor = p.uiColor(i)
            let bg = side(i, 0, sideW - ptW)
            if t.teamRows { fill(c, bg, teamColor.withAlphaComponent(0.9)) }
            fill(c, CGRect(x: bg.minX, y: top + h - 4 * u, width: bg.width, height: 4 * u), teamColor)

            var lx = pad
            if logoW > 0 {
                drawFit(i == 0 ? logoA : logoB, side(i, lx, logoW, 5 * u, h - 10 * u))
                lx += logoW + 8 * u
            }
            if serveW > 0 {
                if e.s.server == i {
                    let r = side(i, lx, serveW)
                    UIColor(hex: 0xFFD7F205).setFill()
                    UIBezierPath(ovalIn: CGRect(x: r.midX - 5 * u, y: r.midY - 5 * u, width: 10 * u, height: 10 * u)).fill()
                }
                lx += serveW
            }
            var nameColor = t.teamRows ? textOn(teamColor) : t.fg
            if e.s.finished && e.s.winner != i { nameColor = t.teamRows ? UIColor(white: 1, alpha: 0.6) : t.dim }
            let nr = side(i, lx, nameW)
            drawText(ellipsize(i == 0 ? p.nameA : p.nameB, nameFont, nameW - 10 * u), nameFont, nameColor,
                     x: i == 0 ? nr.minX : nr.maxX, cy: top + h / 2, align: i == 0 ? .left : .right, t: t, glow: false)
            lx += nameW

            for k in 0..<finished {
                let set = e.s.sets[k]
                let r = side(i, lx + CGFloat(k) * setCell, setCell)
                let col = set[i] > set[1 - i] ? (t.teamRows ? textOn(teamColor) : t.fg) : (t.teamRows ? UIColor(white: 1, alpha: 0.6) : t.dim)
                drawText("\(set[i])", .boldSystemFont(ofSize: 18 * u), col, x: r.midX, cy: top + h / 2, align: .center, t: t, glow: false)
            }
            lx += CGFloat(finished) * setCell
            if gameCell > 0 {
                let r = side(i, lx, gameCell)
                drawText("\(e.s.games[i])", .boldSystemFont(ofSize: 24 * u), t.teamRows ? textOn(teamColor) : t.fg,
                         x: r.midX, cy: top + h / 2, align: .center, t: t, glow: false)
                lx += gameCell
            }
            let pr = side(i, lx, ptW)
            fill(c, pr, t.ptBg)
            drawText(e.pointLabel(i), .boldSystemFont(ofSize: 32 * u), t.ptFg, x: pr.midX, cy: top + h / 2, align: .center, t: t, glow: t.glow)
        }

        let cr = CGRect(x: left + sideW, y: top, width: centerW, height: h)
        fill(c, cr, t.centerBg)
        drawText(center, centerFont, isClock ? clockColor(e, p, t) : .white, x: cr.midX, cy: cr.midY, align: .center, t: t, glow: t.glow)
        c.restoreGState()
        drawStroke(box, u, t)

        if isClock && !info.isEmpty {
            let f = UIFont.boldSystemFont(ofSize: 15 * u)
            let tw = width(info, f) + 24 * u, th = 26 * u
            let below = !p.position.hasPrefix("B")
            let tab = CGRect(x: cr.midX - tw / 2, y: below ? box.maxY : box.minY - th, width: tw, height: th)
            (t.glow ? UIColor(hex: 0xFF00E5FF) : (p.style == "LIGHT" ? UIColor(hex: 0xFF101820) : UIColor(hex: 0xFF12A183))).setFill()
            UIBezierPath(roundedRect: tab, cornerRadius: 6 * u).fill()
            drawText(info, f, t.glow ? .black : .white, x: tab.midX, cy: tab.midY, align: .center, t: Theme(), glow: false)
            box = box.union(tab)
        }
    }

    // MARK: sponsors
    private func drawSponsors(_ S: CGSize, _ u: CGFloat, _ margin: CGFloat, _ p: Settings) {
        let maxH = 80 * u, gap = 12 * u
        let right = p.position != "TR"
        let bottom = p.position == "TC"
        let y = bottom ? S.height - margin - maxH : margin
        var x = right ? S.width - margin : margin
        for img in [logo1, logo2].compactMap({ $0 }) {
            let scale = min(maxH / img.size.height, 260 * u / img.size.width)
            let w = img.size.width * scale, h = img.size.height * scale
            let yy = bottom ? y + (maxH - h) : y
            img.draw(in: right ? CGRect(x: x - w, y: yy, width: w, height: h) : CGRect(x: x, y: yy, width: w, height: h))
            x = right ? x - w - gap : x + w + gap
        }
    }

    // MARK: helpers
    private func serveVisible(_ e: ScoreEngine, _ p: Settings) -> Bool { p.showServe && e.rules.sport.kind != .goals && !e.s.finished }
    private func teamLogosVisible(_ p: Settings) -> Bool { p.showTeamLogos && (logoA != nil || logoB != nil) }

    private func clockVisible(_ e: ScoreEngine, _ p: Settings) -> Bool {
        guard p.showClock else { return false }
        return e.rules.sport.kind == .goals || e.clockRunning || e.clockMs > 0 || p.clockMode == "DOWN"
    }

    private func clockColor(_ e: ScoreEngine, _ p: Settings, _ t: Theme) -> UIColor {
        if p.clockMode == "DOWN" && p.shownClock(e) <= 60_000 && e.clockRunning { return UIColor(hex: 0xFFFF5A4E) }
        if !e.clockRunning && e.clockMs > 0 { return t.glow ? UIColor(hex: 0xFF5F7B88) : UIColor(hex: 0xFFF2C94C) }
        if t.glow { return UIColor(hex: 0xFF00E5FF) }
        return p.style == "LIGHT" ? UIColor(hex: 0xFF101820) : .white
    }

    private func infoText(_ e: ScoreEngine, _ p: Settings) -> String {
        var parts: [String] = []
        if !e.phaseLabel.isEmpty { parts.append(e.phaseLabel) }
        if p.showPeriod && e.rules.sport.kind == .goals { parts.append(e.periodLabel) }
        return parts.joined(separator: "  ·  ")
    }

    private func place(_ w: CGFloat, _ h: CGFloat, _ S: CGSize, _ margin: CGFloat, _ pos: String) -> CGRect {
        let x = pos.hasSuffix("L") ? margin : pos.hasSuffix("R") ? S.width - w - margin : (S.width - w) / 2
        let y = pos.hasPrefix("B") ? S.height - h - margin : margin
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func drawBackground(_ c: CGContext, _ box: CGRect, _ u: CGFloat, _ t: Theme) {
        if t.noBackground { return }
        c.saveGState()
        if t.glow, let s = t.stroke { c.setShadow(offset: .zero, blur: 14 * u, color: s.withAlphaComponent(0.6).cgColor) }
        else { c.setShadow(offset: CGSize(width: 0, height: 3 * u), blur: 6 * u, color: UIColor(white: 0, alpha: 0.35).cgColor) }
        t.bg.setFill()
        UIBezierPath(roundedRect: box, cornerRadius: t.radius * u).fill()
        c.restoreGState()
    }

    private func drawStroke(_ box: CGRect, _ u: CGFloat, _ t: Theme) {
        guard let s = t.stroke else { return }
        s.setStroke()
        let path = UIBezierPath(roundedRect: box.insetBy(dx: u, dy: u), cornerRadius: t.radius * u)
        path.lineWidth = 2 * u
        path.stroke()
    }

    private func fill(_ c: CGContext, _ r: CGRect, _ color: UIColor) {
        guard color.alpha > 0 else { return }
        c.setFillColor(color.cgColor)
        c.fill(r)
    }

    private func drawFit(_ img: UIImage?, _ area: CGRect) {
        guard let img, img.size.width > 0, img.size.height > 0 else { return }
        let s = min(area.width / img.size.width, area.height / img.size.height)
        let w = img.size.width * s, h = img.size.height * s
        img.draw(in: CGRect(x: area.midX - w / 2, y: area.midY - h / 2, width: w, height: h))
    }

    private func width(_ s: String, _ f: UIFont) -> CGFloat { (s as NSString).size(withAttributes: [.font: f]).width }

    private func ellipsize(_ s: String, _ f: UIFont, _ maxW: CGFloat) -> String {
        if width(s, f) <= maxW { return s }
        var str = s
        while str.count > 1 && width(str + "…", f) > maxW { str.removeLast() }
        return str + "…"
    }

    private func drawText(_ s: String, _ f: UIFont, _ color: UIColor, x: CGFloat, cy: CGFloat, align: NSTextAlignment, t: Theme, glow: Bool) {
        var attrs: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: color]
        if glow {
            let sh = NSShadow(); sh.shadowColor = color; sh.shadowBlurRadius = f.pointSize * 0.35; sh.shadowOffset = .zero
            attrs[.shadow] = sh
        } else if t.textShadow {
            let sh = NSShadow(); sh.shadowColor = UIColor(white: 0, alpha: 0.8); sh.shadowBlurRadius = f.pointSize * 0.18
            sh.shadowOffset = CGSize(width: 0, height: f.pointSize * 0.06)
            attrs[.shadow] = sh
        }
        let size = (s as NSString).size(withAttributes: attrs)
        let ox: CGFloat = align == .center ? x - size.width / 2 : align == .right ? x - size.width : x
        (s as NSString).draw(at: CGPoint(x: ox, y: cy - size.height / 2), withAttributes: attrs)
    }

    private func textOn(_ bg: UIColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        bg.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (0.299 * r + 0.587 * g + 0.114 * b) > 0.67 ? UIColor(hex: 0xFF101820) : .white
    }
}

extension UIColor {
    /// 0xAARRGGBB
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: CGFloat((hex >> 24) & 0xFF) / 255)
    }
    var alpha: CGFloat { cgColor.alpha }
}
