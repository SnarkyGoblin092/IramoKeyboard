import CoreGraphics

/// The pictures the particle effects are made of, drawn as vector shapes (never emoji or text), so the keyboard
/// (Core Animation) and the Effects screen (SwiftUI) draw exactly the same thing, in the press's colour.
enum EffectArt: Hashable {
    case heart, star, sparkle, ninja, pinwheel, snowflake, seed, note, flower, petal, leaf, butterfly
    case coin, gem, balloon, ghost, rocket, crown, arrow, check
    case spade, club, diamond
    case die(Int)
    case smiley
    case bit(Bool)

    /// Whether it points somewhere (it is turned with the direction the effect goes in).
    var isOriented: Bool {
        switch self {
        case .rocket, .arrow: return true
        default: return false
        }
    }

    /// Whether its holes are cut out (even-odd) instead of everything inside being filled.
    var cutsHoles: Bool {
        switch self {
        case .ninja, .leaf, .coin, .gem, .ghost, .rocket, .die, .smiley, .bit(false): return true
        default: return false
        }
    }

    /// The shape in a square of `side`, its middle at the square's middle.
    func path(side s: CGFloat) -> CGPath {
        let unit = unitPath()
        var scale = CGAffineTransform(scaleX: s, y: s)
        return unit.copy(using: &scale) ?? unit
    }

    // MARK: Drawing (in a 1 x 1 square)

    private func unitPath() -> CGPath {
        let p = CGMutablePath()
        switch self {
        case .heart:
            addHeart(p)
        case .star:
            addStar(p, points: 5, inner: 0.42)
        case .sparkle:
            addStar(p, points: 4, inner: 0.2)
        case .ninja:
            addStar(p, points: 4, inner: 0.32)
            p.addEllipse(in: CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2))
        case .pinwheel:
            addStar(p, points: 6, inner: 0.36)
        case .snowflake:
            let arms = CGMutablePath()
            for k in 0..<6 {
                let a = CGFloat(k) * .pi / 3
                let tip = CGPoint(x: 0.5 + cos(a) * 0.47, y: 0.5 + sin(a) * 0.47)
                arms.move(to: CGPoint(x: 0.5, y: 0.5))
                arms.addLine(to: tip)
                for side in [-1, 1] as [CGFloat] {
                    let base = CGPoint(x: 0.5 + cos(a) * 0.3, y: 0.5 + sin(a) * 0.3)
                    arms.move(to: base)
                    arms.addLine(to: CGPoint(x: base.x + cos(a + side * 0.9) * 0.14, y: base.y + sin(a + side * 0.9) * 0.14))
                }
            }
            p.addPath(arms.copy(strokingWithWidth: 0.07, lineCap: .round, lineJoin: .round, miterLimit: 4))
        case .seed:
            let fluff = CGMutablePath()
            for k in 0..<7 {
                let a = CGFloat(k) * 2 * .pi / 7 - .pi / 2
                fluff.move(to: CGPoint(x: 0.5, y: 0.5))
                fluff.addLine(to: CGPoint(x: 0.5 + cos(a) * 0.45, y: 0.5 + sin(a) * 0.45))
            }
            p.addPath(fluff.copy(strokingWithWidth: 0.045, lineCap: .round, lineJoin: .round, miterLimit: 4))
            p.addEllipse(in: CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2))
        case .note:
            p.addEllipse(in: CGRect(x: 0.1, y: 0.62, width: 0.4, height: 0.3))
            let stem = CGMutablePath()
            stem.move(to: CGPoint(x: 0.47, y: 0.78))
            stem.addLine(to: CGPoint(x: 0.47, y: 0.1))
            stem.addCurve(to: CGPoint(x: 0.82, y: 0.52), control1: CGPoint(x: 0.5, y: 0.34), control2: CGPoint(x: 0.84, y: 0.3))
            p.addPath(stem.copy(strokingWithWidth: 0.09, lineCap: .round, lineJoin: .round, miterLimit: 4))
        case .flower:
            for k in 0..<5 {
                let a = CGFloat(k) * 2 * .pi / 5 - .pi / 2
                let petal = CGMutablePath()
                petal.addEllipse(in: CGRect(x: -0.14, y: -0.3, width: 0.28, height: 0.3))
                p.addPath(petal, transform: CGAffineTransform(translationX: 0.5, y: 0.5).rotated(by: a + .pi / 2))
            }
            p.addEllipse(in: CGRect(x: 0.38, y: 0.38, width: 0.24, height: 0.24))
        case .petal:
            p.move(to: CGPoint(x: 0.5, y: 0.04))
            p.addCurve(to: CGPoint(x: 0.5, y: 0.96), control1: CGPoint(x: 0.98, y: 0.3), control2: CGPoint(x: 0.86, y: 0.82))
            p.addCurve(to: CGPoint(x: 0.5, y: 0.04), control1: CGPoint(x: 0.14, y: 0.82), control2: CGPoint(x: 0.02, y: 0.3))
            p.closeSubpath()
        case .leaf:
            p.move(to: CGPoint(x: 0.5, y: 0.02))
            p.addCurve(to: CGPoint(x: 0.5, y: 0.98), control1: CGPoint(x: 1.02, y: 0.28), control2: CGPoint(x: 0.96, y: 0.82))
            p.addCurve(to: CGPoint(x: 0.5, y: 0.02), control1: CGPoint(x: 0.04, y: 0.82), control2: CGPoint(x: -0.02, y: 0.28))
            p.closeSubpath()
            let vein = CGMutablePath()
            vein.move(to: CGPoint(x: 0.5, y: 0.24))
            vein.addLine(to: CGPoint(x: 0.5, y: 0.9))
            p.addPath(vein.copy(strokingWithWidth: 0.04, lineCap: .round, lineJoin: .round, miterLimit: 4))
        case .butterfly:
            for sign in [-1, 1] as [CGFloat] {
                let upper = CGMutablePath()
                upper.addEllipse(in: CGRect(x: -0.26, y: -0.2, width: 0.52, height: 0.4))
                p.addPath(upper, transform: CGAffineTransform(translationX: 0.5 + sign * 0.25, y: 0.36).rotated(by: sign * -0.35))
                let lower = CGMutablePath()
                lower.addEllipse(in: CGRect(x: -0.17, y: -0.15, width: 0.34, height: 0.3))
                p.addPath(lower, transform: CGAffineTransform(translationX: 0.5 + sign * 0.17, y: 0.69).rotated(by: sign * 0.3))
            }
            p.addRoundedRect(in: CGRect(x: 0.46, y: 0.22, width: 0.08, height: 0.62), cornerWidth: 0.04, cornerHeight: 0.04)
        case .coin:
            p.addEllipse(in: CGRect(x: 0, y: 0, width: 1, height: 1))
            p.addEllipse(in: CGRect(x: 0.12, y: 0.12, width: 0.76, height: 0.76))
            p.addEllipse(in: CGRect(x: 0.27, y: 0.27, width: 0.46, height: 0.46))
        case .gem:
            p.move(to: CGPoint(x: 0.22, y: 0.1))
            p.addLine(to: CGPoint(x: 0.78, y: 0.1))
            p.addLine(to: CGPoint(x: 1, y: 0.38))
            p.addLine(to: CGPoint(x: 0.5, y: 0.96))
            p.addLine(to: CGPoint(x: 0, y: 0.38))
            p.closeSubpath()
            let facets = CGMutablePath()
            facets.move(to: CGPoint(x: 0, y: 0.38))
            facets.addLine(to: CGPoint(x: 1, y: 0.38))
            facets.move(to: CGPoint(x: 0.36, y: 0.1))
            facets.addLine(to: CGPoint(x: 0.28, y: 0.38))
            facets.addLine(to: CGPoint(x: 0.5, y: 0.96))
            facets.move(to: CGPoint(x: 0.64, y: 0.1))
            facets.addLine(to: CGPoint(x: 0.72, y: 0.38))
            facets.addLine(to: CGPoint(x: 0.5, y: 0.96))
            p.addPath(facets.copy(strokingWithWidth: 0.03, lineCap: .butt, lineJoin: .miter, miterLimit: 4))
        case .balloon:
            p.addEllipse(in: CGRect(x: 0.18, y: 0.02, width: 0.64, height: 0.76))
            p.move(to: CGPoint(x: 0.5, y: 0.76))
            p.addLine(to: CGPoint(x: 0.42, y: 0.88))
            p.addLine(to: CGPoint(x: 0.58, y: 0.88))
            p.closeSubpath()
            let string = CGMutablePath()
            string.move(to: CGPoint(x: 0.5, y: 0.88))
            string.addCurve(to: CGPoint(x: 0.5, y: 1), control1: CGPoint(x: 0.4, y: 0.92), control2: CGPoint(x: 0.6, y: 0.96))
            p.addPath(string.copy(strokingWithWidth: 0.03, lineCap: .round, lineJoin: .round, miterLimit: 4))
        case .ghost:
            p.move(to: CGPoint(x: 0.1, y: 0.92))
            p.addLine(to: CGPoint(x: 0.1, y: 0.46))
            p.addArc(center: CGPoint(x: 0.5, y: 0.46), radius: 0.4, startAngle: .pi, endAngle: 0, clockwise: false)
            p.addLine(to: CGPoint(x: 0.9, y: 0.92))
            p.addQuadCurve(to: CGPoint(x: 0.7, y: 0.84), control: CGPoint(x: 0.82, y: 0.78))
            p.addQuadCurve(to: CGPoint(x: 0.5, y: 0.92), control: CGPoint(x: 0.6, y: 0.98))
            p.addQuadCurve(to: CGPoint(x: 0.3, y: 0.84), control: CGPoint(x: 0.4, y: 0.78))
            p.addQuadCurve(to: CGPoint(x: 0.1, y: 0.92), control: CGPoint(x: 0.18, y: 0.98))
            p.closeSubpath()
            p.addEllipse(in: CGRect(x: 0.28, y: 0.34, width: 0.14, height: 0.18))
            p.addEllipse(in: CGRect(x: 0.58, y: 0.34, width: 0.14, height: 0.18))
        case .rocket:
            p.move(to: CGPoint(x: 0.5, y: 0))
            p.addCurve(to: CGPoint(x: 0.68, y: 0.62), control1: CGPoint(x: 0.68, y: 0.16), control2: CGPoint(x: 0.7, y: 0.4))
            p.addLine(to: CGPoint(x: 0.68, y: 0.8))
            p.addLine(to: CGPoint(x: 0.32, y: 0.8))
            p.addLine(to: CGPoint(x: 0.32, y: 0.62))
            p.addCurve(to: CGPoint(x: 0.5, y: 0), control1: CGPoint(x: 0.3, y: 0.4), control2: CGPoint(x: 0.32, y: 0.16))
            p.closeSubpath()
            p.move(to: CGPoint(x: 0.32, y: 0.5))
            p.addLine(to: CGPoint(x: 0.1, y: 0.86))
            p.addLine(to: CGPoint(x: 0.32, y: 0.78))
            p.closeSubpath()
            p.move(to: CGPoint(x: 0.68, y: 0.5))
            p.addLine(to: CGPoint(x: 0.9, y: 0.86))
            p.addLine(to: CGPoint(x: 0.68, y: 0.78))
            p.closeSubpath()
            p.move(to: CGPoint(x: 0.4, y: 0.84))
            p.addLine(to: CGPoint(x: 0.6, y: 0.84))
            p.addLine(to: CGPoint(x: 0.5, y: 1))
            p.closeSubpath()
            p.addEllipse(in: CGRect(x: 0.41, y: 0.26, width: 0.18, height: 0.18))
        case .crown:
            p.move(to: CGPoint(x: 0.04, y: 0.82))
            p.addLine(to: CGPoint(x: 0.04, y: 0.28))
            p.addLine(to: CGPoint(x: 0.28, y: 0.54))
            p.addLine(to: CGPoint(x: 0.5, y: 0.12))
            p.addLine(to: CGPoint(x: 0.72, y: 0.54))
            p.addLine(to: CGPoint(x: 0.96, y: 0.28))
            p.addLine(to: CGPoint(x: 0.96, y: 0.82))
            p.closeSubpath()
        case .arrow:
            let arrow = CGMutablePath()
            arrow.move(to: CGPoint(x: 0.5, y: 0.96))
            arrow.addLine(to: CGPoint(x: 0.5, y: 0.12))
            arrow.move(to: CGPoint(x: 0.16, y: 0.46))
            arrow.addLine(to: CGPoint(x: 0.5, y: 0.1))
            arrow.addLine(to: CGPoint(x: 0.84, y: 0.46))
            p.addPath(arrow.copy(strokingWithWidth: 0.14, lineCap: .round, lineJoin: .round, miterLimit: 4))
        case .check:
            let tick = CGMutablePath()
            tick.move(to: CGPoint(x: 0.12, y: 0.54))
            tick.addLine(to: CGPoint(x: 0.4, y: 0.82))
            tick.addLine(to: CGPoint(x: 0.88, y: 0.2))
            p.addPath(tick.copy(strokingWithWidth: 0.17, lineCap: .round, lineJoin: .round, miterLimit: 4))
        case .spade:
            let top = CGMutablePath()
            addHeart(top)
            var flip = CGAffineTransform(translationX: 0, y: 1).scaledBy(x: 1, y: -1)
            if let flipped = top.copy(using: &flip) { p.addPath(flipped, transform: CGAffineTransform(translationX: 0, y: -0.06)) }
            p.move(to: CGPoint(x: 0.5, y: 0.6))
            p.addLine(to: CGPoint(x: 0.36, y: 0.98))
            p.addLine(to: CGPoint(x: 0.64, y: 0.98))
            p.closeSubpath()
        case .club:
            p.addEllipse(in: CGRect(x: 0.32, y: 0.02, width: 0.36, height: 0.36))
            p.addEllipse(in: CGRect(x: 0.08, y: 0.34, width: 0.36, height: 0.36))
            p.addEllipse(in: CGRect(x: 0.56, y: 0.34, width: 0.36, height: 0.36))
            p.move(to: CGPoint(x: 0.5, y: 0.45))
            p.addLine(to: CGPoint(x: 0.36, y: 0.98))
            p.addLine(to: CGPoint(x: 0.64, y: 0.98))
            p.closeSubpath()
        case .diamond:
            p.move(to: CGPoint(x: 0.5, y: 0))
            p.addLine(to: CGPoint(x: 0.9, y: 0.5))
            p.addLine(to: CGPoint(x: 0.5, y: 1))
            p.addLine(to: CGPoint(x: 0.1, y: 0.5))
            p.closeSubpath()
        case .die(let face):
            p.addRoundedRect(in: CGRect(x: 0.04, y: 0.04, width: 0.92, height: 0.92), cornerWidth: 0.2, cornerHeight: 0.2)
            let a: CGFloat = 0.27, b: CGFloat = 0.5, c: CGFloat = 0.73
            let spots: [[CGPoint]] = [
                [CGPoint(x: b, y: b)],
                [CGPoint(x: a, y: a), CGPoint(x: c, y: c)],
                [CGPoint(x: a, y: a), CGPoint(x: b, y: b), CGPoint(x: c, y: c)],
                [CGPoint(x: a, y: a), CGPoint(x: c, y: a), CGPoint(x: a, y: c), CGPoint(x: c, y: c)],
                [CGPoint(x: a, y: a), CGPoint(x: c, y: a), CGPoint(x: b, y: b), CGPoint(x: a, y: c), CGPoint(x: c, y: c)],
                [CGPoint(x: a, y: a), CGPoint(x: c, y: a), CGPoint(x: a, y: b), CGPoint(x: c, y: b), CGPoint(x: a, y: c), CGPoint(x: c, y: c)],
            ]
            for spot in spots[min(max(face, 0), 5)] {
                p.addEllipse(in: CGRect(x: spot.x - 0.075, y: spot.y - 0.075, width: 0.15, height: 0.15))
            }
        case .smiley:
            p.addEllipse(in: CGRect(x: 0, y: 0, width: 1, height: 1))
            p.addEllipse(in: CGRect(x: 0.28, y: 0.3, width: 0.14, height: 0.18))
            p.addEllipse(in: CGRect(x: 0.58, y: 0.3, width: 0.14, height: 0.18))
            let smile = CGMutablePath()
            smile.addArc(center: CGPoint(x: 0.5, y: 0.5), radius: 0.27, startAngle: 0.5, endAngle: .pi - 0.5, clockwise: false)
            p.addPath(smile.copy(strokingWithWidth: 0.07, lineCap: .round, lineJoin: .round, miterLimit: 4))
        case .bit(let one):
            if one {
                let mark = CGMutablePath()
                mark.move(to: CGPoint(x: 0.3, y: 0.22))
                mark.addLine(to: CGPoint(x: 0.52, y: 0.06))
                mark.addLine(to: CGPoint(x: 0.52, y: 0.94))
                p.addPath(mark.copy(strokingWithWidth: 0.16, lineCap: .round, lineJoin: .round, miterLimit: 4))
            } else {
                p.addEllipse(in: CGRect(x: 0.18, y: 0.02, width: 0.64, height: 0.96))
                p.addEllipse(in: CGRect(x: 0.34, y: 0.2, width: 0.32, height: 0.6))
            }
        }
        return p
    }

    private func addHeart(_ p: CGMutablePath) {
        p.move(to: CGPoint(x: 0.5, y: 0.94))
        p.addCurve(to: CGPoint(x: 0.03, y: 0.34), control1: CGPoint(x: 0.28, y: 0.76), control2: CGPoint(x: 0.03, y: 0.58))
        p.addCurve(to: CGPoint(x: 0.5, y: 0.26), control1: CGPoint(x: 0.03, y: 0.04), control2: CGPoint(x: 0.42, y: 0.08))
        p.addCurve(to: CGPoint(x: 0.97, y: 0.34), control1: CGPoint(x: 0.58, y: 0.08), control2: CGPoint(x: 0.97, y: 0.04))
        p.addCurve(to: CGPoint(x: 0.5, y: 0.94), control1: CGPoint(x: 0.97, y: 0.58), control2: CGPoint(x: 0.72, y: 0.76))
        p.closeSubpath()
    }

    private func addStar(_ p: CGMutablePath, points: Int, inner: CGFloat) {
        for k in 0..<(points * 2) {
            let radius: CGFloat = k % 2 == 0 ? 0.5 : 0.5 * inner
            let angle = CGFloat(k) * .pi / CGFloat(points) - .pi / 2
            let point = CGPoint(x: 0.5 + cos(angle) * radius, y: 0.5 + sin(angle) * radius)
            if k == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
    }
}

/// The colours an effect can have: one colour (the accent, white or the user's own) or a spread of them.
enum EffectPalette {
    static let modes = ["accent", "white", "rainbow", "warm", "cool", "pastel", "neon", "random", "custom"]

    /// Whether every press (or every speck) gets a colour of its own.
    static func isMulti(_ mode: String) -> Bool {
        return ["rainbow", "warm", "cool", "pastel", "neon", "random"].contains(mode)
    }

    /// The hue, saturation and brightness of one colour of the palette; `h` is a number in 0..<1 picking it.
    static func tint(_ mode: String, _ h: CGFloat) -> EffectTint {
        let h = h - floor(h)
        switch mode {
        case "warm": return EffectTint(h: h * 0.14, s: 0.85, b: 1)
        case "cool": return EffectTint(h: 0.48 + h * 0.3, s: 0.75, b: 1)
        case "pastel": return EffectTint(h: h, s: 0.32, b: 1)
        case "neon": return EffectTint(h: h, s: 1, b: 1)
        default: return EffectTint(h: h, s: 0.75, b: 1)
        }
    }

    /// A plain colour as a tint.
    static func tint(of color: ThemeRGBA) -> EffectTint {
        let high = max(color.r, color.g, color.b)
        let low = min(color.r, color.g, color.b)
        let delta = high - low
        var hue = 0.0
        if delta > 0 {
            if high == color.r { hue = ((color.g - color.b) / delta).truncatingRemainder(dividingBy: 6) }
            else if high == color.g { hue = (color.b - color.r) / delta + 2 }
            else { hue = (color.r - color.g) / delta + 4 }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return EffectTint(h: CGFloat(hue), s: CGFloat(high == 0 ? 0 : delta / high), b: CGFloat(high))
    }
}

/// A colour as hue, saturation and brightness (0...1 each).
struct EffectTint: Hashable {
    var h: CGFloat
    var s: CGFloat
    var b: CGFloat
}

/// Where on the key the effects start: the Effects screen's position setting moves the effects that leave the key
/// (specks, sparks, confetti, bubbles, the echo, the shockwave, the bolt) and the ripple.
enum EffectPosition {
    static let choices = ["auto", "top", "bottom", "left", "right", "random"]

    /// How far from the middle of a key of `size` the effects start. `random` gives two numbers in 0..<1, taken afresh.
    static func offset(_ mode: String, size: CGSize, random: () -> CGFloat) -> CGPoint {
        let dx = size.width * 0.38
        let dy = size.height * 0.36
        switch mode {
        case "top": return CGPoint(x: 0, y: -dy)
        case "bottom": return CGPoint(x: 0, y: dy)
        case "left": return CGPoint(x: -dx, y: 0)
        case "right": return CGPoint(x: dx, y: 0)
        case "random": return CGPoint(x: (random() * 2 - 1) * dx, y: (random() * 2 - 1) * dy)
        default: return .zero
        }
    }
}

/// Where the effects go: the Effects screen's direction setting turns each effect that has a way of its own (up,
/// down, sideways) to the chosen direction; effects that spread evenly in every direction stay as they are.
enum EffectDirection {
    static let choices = ["auto", "up", "down", "left", "right", "random"]

    /// The angle the effects should go at, from straight up, clockwise (up 0, right a quarter turn, down half),
    /// nil to leave them as designed. `random` is a number in 0..<1, taken afresh for "random".
    static func target(_ mode: String, random: () -> CGFloat) -> CGFloat? {
        switch mode {
        case "up": return 0
        case "right": return .pi / 2
        case "down": return .pi
        case "left": return 3 * .pi / 2
        case "random": return random() * 2 * .pi
        default: return nil
        }
    }

    /// `point` turned clockwise by `angle`.
    static func turn(_ point: CGPoint, by angle: CGFloat) -> CGPoint {
        let c = cos(angle), s = sin(angle)
        return CGPoint(x: point.x * c - point.y * s, y: point.x * s + point.y * c)
    }

    /// The way a path heads in its first stretch, from straight up, clockwise; nil when it hardly moves.
    static func heading(_ path: (CGFloat) -> CGPoint, scale: CGFloat) -> CGPoint? {
        let a = path(0)
        let b = path(0.3)
        let d = CGPoint(x: b.x - a.x, y: b.y - a.y)
        return hypot(d.x, d.y) > scale * 0.05 ? d : nil
    }
}
