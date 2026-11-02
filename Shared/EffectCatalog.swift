import CoreGraphics

// MARK: - Settings of the catalog's effects

/// One setting of a catalog effect: what the Effects screen shows as a slider.
struct EffectParam {
    enum Format {
        case number, times, seconds, points, keys, percent

        func text(_ value: Double) -> String {
            switch self {
            case .number: return "\(Int(value.rounded()))"
            case .times: return String(format: "%.1f\u{00D7}", value)
            case .seconds: return String(format: "%.2f s", value)
            case .points: return "\(Int(value.rounded())) pt"
            case .keys: return String(format: "%.1f keys", value)
            case .percent: return String(format: "%.0f%%", value * 100)
            }
        }
    }

    let id: String
    let title: String
    let symbol: String
    let range: ClosedRange<Double>
    let value: Double
    let step: Double
    let format: Format
}

/// An effect of the catalog: a switch with a few settings, drawn from particles (EffectParticle) by both the keyboard
/// and the Effects screen's keyboard, so each is described only once.
struct EffectEntry {
    let id: String
    let title: String
    let note: String
    let symbol: String
    /// A colour name the Effects screen turns into a colour.
    let color: String
    /// Its sliders: how many, how big, how fast, and sometimes one of its own.
    let params: [EffectParam]
    let build: (EffectContext) -> [EffectParticle]
}

/// What an effect needs to build the particles of one press.
struct EffectContext {
    let w: CGFloat
    let h: CGFloat
    /// The Count setting.
    let n: Int
    /// The Size and Speed settings (1 = as designed).
    let size: CGFloat
    let speed: Double
    /// The effect's own setting (1 when it has none).
    let extra: CGFloat
    let seed: Int
    let rainbow: Bool
    let random: (Int, Int) -> CGFloat

    func r(_ i: Int, _ salt: Int) -> CGFloat { return random(seed + i, salt) }

    func between(_ low: CGFloat, _ high: CGFloat, _ i: Int, _ salt: Int) -> CGFloat {
        return low + (high - low) * r(i, salt)
    }

    /// A hue of its own for each speck when the rainbow colour is chosen.
    func hue(_ i: Int) -> CGFloat? { return rainbow ? r(i, 99) : nil }

    /// One speck, its size, duration and delay changed by the Size and Speed settings.
    func speck(_ shape: EffectParticle.Shape, _ side: CGFloat, _ seconds: Double, delay: Double = 0, spin: CGFloat = 0,
               from: CGFloat = 1, to: CGFloat = 1, peak: CGFloat = 1, hue: CGFloat? = nil,
               path: @escaping (CGFloat) -> CGPoint) -> EffectParticle {
        let pace = max(speed, 0.1)
        return EffectParticle(shape: shape, size: side * size, duration: seconds / pace, delay: delay / pace, spin: spin,
                              scaleFrom: from, scaleTo: to, peak: peak, hue: hue, path: path)
    }
}

// MARK: - Paths

enum EffectPath {
    static func easeOut(_ t: CGFloat) -> CGFloat { return 1 - (1 - t) * (1 - t) }

    /// A walk along straight stretches between `points`, `t` from 0 to 1 over the whole way.
    static func walk(_ points: [CGPoint]) -> (CGFloat) -> CGPoint {
        return { t in
            guard points.count > 1 else { return points.first ?? .zero }
            let scaled = min(max(t, 0), 1) * CGFloat(points.count - 1)
            let index = min(Int(scaled), points.count - 2)
            let local = scaled - CGFloat(index)
            let a = points[index]
            let b = points[index + 1]
            return CGPoint(x: a.x + (b.x - a.x) * local, y: a.y + (b.y - a.y) * local)
        }
    }

    /// Up (negative y) by `height`, swaying sideways.
    static func rise(x: CGFloat, height: CGFloat, sway: CGFloat, phase: CGFloat, turns: CGFloat = 1.2) -> (CGFloat) -> CGPoint {
        return { t in
            let angle: CGFloat = t * 2 * .pi * turns + phase
            return CGPoint(x: x + sin(angle) * sway, y: -height * t)
        }
    }

    /// Down from `top` (negative y) to `bottom`, swaying sideways.
    static func fall(x: CGFloat, top: CGFloat, bottom: CGFloat, sway: CGFloat, phase: CGFloat, turns: CGFloat = 1.5) -> (CGFloat) -> CGPoint {
        return { t in
            let angle: CGFloat = t * 2 * .pi * turns + phase
            return CGPoint(x: x + sin(angle) * sway, y: top + (bottom - top) * t)
        }
    }

    /// Out along `angle` by `distance`, slowing down, with gravity pulling down.
    static func burst(angle: CGFloat, distance: CGFloat, gravity: CGFloat = 0) -> (CGFloat) -> CGPoint {
        return { t in
            let out = easeOut(t)
            let dx: CGFloat = cos(angle) * distance * out
            let dy: CGFloat = sin(angle) * distance * out + gravity * t * t
            return CGPoint(x: dx, y: dy)
        }
    }

    /// A throw: `dx`, `dy` over the flight, and gravity.
    static func throwing(dx: CGFloat, dy: CGFloat, gravity: CGFloat) -> (CGFloat) -> CGPoint {
        return { t in CGPoint(x: dx * t, y: dy * t + gravity * t * t / 2) }
    }

    /// Round an ellipse centred at `center`, `turns` times.
    static func orbit(center: CGPoint, rx: CGFloat, ry: CGFloat, start: CGFloat, turns: CGFloat) -> (CGFloat) -> CGPoint {
        return { t in
            let angle: CGFloat = start + 2 * .pi * turns * t
            return CGPoint(x: center.x + cos(angle) * rx, y: center.y + sin(angle) * ry)
        }
    }

    /// A spiral from radius `from` to `to`, turning `turns` times.
    static func spiral(start: CGFloat, from: CGFloat, to: CGFloat, turns: CGFloat) -> (CGFloat) -> CGPoint {
        return { t in
            let angle: CGFloat = start + 2 * .pi * turns * t
            let radius: CGFloat = from + (to - from) * t
            return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
    }
}

// MARK: - The catalog

enum EffectCatalog {
    private static func count(_ value: Double, _ range: ClosedRange<Double>) -> EffectParam {
        return EffectParam(id: "count", title: "Count", symbol: "number", range: range, value: value, step: 1, format: .number)
    }

    private static let sizeParam = EffectParam(id: "size", title: "Size", symbol: "circle.fill", range: 0.5...2, value: 1, step: 0.1, format: .times)
    private static let speedParam = EffectParam(id: "speed", title: "Speed", symbol: "speedometer", range: 0.5...2.5, value: 1, step: 0.1, format: .times)

    private static func times(_ id: String, _ title: String, _ symbol: String, _ range: ClosedRange<Double> = 0.5...2) -> EffectParam {
        return EffectParam(id: id, title: title, symbol: symbol, range: range, value: 1, step: 0.1, format: .times)
    }

    private static func entry(_ id: String, _ title: String, _ note: String, _ symbol: String, _ color: String,
                              count value: Double, _ range: ClosedRange<Double>, extra: EffectParam? = nil,
                              build: @escaping (EffectContext) -> [EffectParticle]) -> EffectEntry {
        var params = [count(value, range), sizeParam, speedParam]
        if let extra = extra { params.append(extra) }
        return EffectEntry(id: id, title: title, note: note, symbol: symbol, color: color, params: params, build: build)
    }

    static let all: [EffectEntry] = [
        // Space
        entry("comet", "Comet", "A comet with a glowing tail streaks past the key.", "moon.stars.fill", "indigo",
              count: 10, 4...16, extra: times("length", "Length", "ruler"), build: comet),
        entry("meteors", "Meteor shower", "Streaks of light fall diagonally past the key.", "sparkles", "orange",
              count: 6, 2...14, build: meteors),
        entry("galaxy", "Galaxy", "Stardust swirls out of the key in spiral arms.", "hurricane", "purple",
              count: 24, 8...48,
              extra: EffectParam(id: "arms", title: "Arms", symbol: "asterisk", range: 2...5, value: 3, step: 1, format: .number),
              build: galaxy),
        entry("nebula", "Nebula", "Soft clouds of colour drift out of the key and fade.", "cloud.fill", "pink",
              count: 6, 2...12, extra: times("spread", "Spread", "arrow.up.left.and.arrow.down.right"), build: nebula),
        entry("twinkle", "Twinkle", "Little stars blink on and off around the key.", "sparkle", "yellow",
              count: 8, 3...16, extra: times("spread", "Spread", "arrow.up.left.and.arrow.down.right"), build: twinkle),
        entry("planets", "Planets", "Planets circle the key, each on its own ring.", "globe.europe.africa.fill", "blue",
              count: 3, 1...5, extra: times("reach", "Reach", "arrow.up.left.and.arrow.down.right"), build: planets),
        entry("blackhole", "Black hole", "Specks spiral into the middle of the key.", "record.circle.fill", "gray",
              count: 14, 5...30, extra: times("reach", "Reach", "arrow.up.left.and.arrow.down.right"), build: blackhole),
        entry("supernova", "Supernova", "Rings and sparks blow out of the key.", "burst.fill", "red",
              count: 14, 4...30, extra: times("reach", "Reach", "arrow.up.left.and.arrow.down.right", 0.5...2.5), build: supernova),

        // Nature
        entry("petals", "Petals", "Flower petals flutter down past the key.", "leaf.fill", "pink",
              count: 8, 3...18, extra: times("wobble", "Wobble", "waveform"), build: petals),
        entry("leaves", "Leaves", "Leaves tumble down on the breeze.", "leaf", "green",
              count: 6, 2...14, extra: times("wobble", "Wobble", "waveform"), build: leaves),
        entry("sakura", "Cherry blossom", "Blossoms spin down in a spiral.", "camera.macro", "pink",
              count: 8, 3...16, build: sakura),
        entry("butterflies", "Butterflies", "Butterflies flutter up from the key.", "ladybug.fill", "teal",
              count: 4, 1...8, extra: times("wobble", "Wobble", "waveform"), build: butterflies),
        entry("fireflies", "Fireflies", "Fireflies wander around the key and glow.", "lightbulb.fill", "yellow",
              count: 8, 3...18, extra: times("spread", "Spread", "arrow.up.left.and.arrow.down.right"), build: fireflies),
        entry("splash", "Splash", "Drops leap up out of the key and fall back.", "drop.fill", "cyan",
              count: 12, 4...28, extra: times("gravity", "Gravity", "arrow.down.to.line"), build: splash),
        entry("dandelion", "Dandelion", "Seeds are blown away sideways and upwards.", "wind", "mint",
              count: 8, 3...18, extra: times("wobble", "Wobble", "waveform"), build: dandelion),
        entry("flames", "Flames", "Tongues of fire flicker up from the key.", "flame", "red",
              count: 12, 4...26, extra: times("height", "Height", "arrow.up.to.line"), build: flames),
        entry("sparkler", "Sparkler", "Bright sparks spray out in every direction.", "wand.and.stars", "orange",
              count: 22, 8...48, build: sparkler),
        entry("aurora", "Aurora", "Ribbons of light rise and sway above the key.", "rainbow", "green",
              count: 5, 2...10, extra: times("height", "Height", "arrow.up.to.line"), build: aurora),

        // Celebration
        entry("coins", "Coins", "Coins leap out of the key and tumble down.", "dollarsign.circle.fill", "yellow",
              count: 8, 3...18, extra: times("gravity", "Gravity", "arrow.down.to.line"), build: coins),
        entry("gems", "Gems", "Gems are thrown out of the key and sparkle.", "diamond.fill", "cyan",
              count: 10, 3...20, build: gems),
        entry("balloons", "Balloons", "Balloons float up from the key.", "balloon.fill", "red",
              count: 3, 1...7, extra: times("rise", "Rise", "arrow.up"), build: balloons),
        entry("streamers", "Streamers", "Ribbons shoot out and flutter down.", "gift.fill", "purple",
              count: 14, 5...30, extra: times("gravity", "Gravity", "arrow.down.to.line"), build: streamers),
        entry("disco", "Disco", "Coloured squares flash around the key.", "square.grid.3x3.fill", "purple",
              count: 10, 4...24, extra: times("spread", "Spread", "arrow.up.left.and.arrow.down.right"), build: disco),
        entry("glitter", "Glitter", "Tiny glittering specks drift down.", "sparkles", "yellow",
              count: 24, 8...48, build: glitter),
        entry("pixels", "Pixels", "Square pixels burst out and fall.", "square.grid.2x2.fill", "green",
              count: 14, 4...30, build: pixels),
        entry("rainbowburst", "Rainbow burst", "Rays in every colour shoot out of the key.", "rainbow", "pink",
              count: 14, 6...30, extra: times("reach", "Reach", "arrow.up.left.and.arrow.down.right"), build: rainbowBurst),

        // Tech
        entry("matrix", "Matrix", "Digits rain down past the key.", "chevron.left.forwardslash.chevron.right", "green",
              count: 10, 4...24, build: matrix),
        entry("sonar", "Sonar", "Rings ping out of the key one after another.", "dot.radiowaves.left.and.right", "teal",
              count: 3, 1...6, extra: times("reach", "Reach", "arrow.up.left.and.arrow.down.right", 0.5...3), build: sonar),
        entry("circuit", "Circuit", "Sparks run along the traces of a circuit board.", "cpu", "mint",
              count: 5, 2...12, extra: times("length", "Length", "ruler"), build: circuit),
        entry("hologram", "Hologram", "Scan lines sweep down over the key.", "square.stack.3d.up.fill", "cyan",
              count: 6, 2...14, build: hologram),
        entry("static", "Static", "Bits of noise flicker around the key.", "tv", "gray",
              count: 16, 6...40, extra: times("spread", "Spread", "arrow.up.left.and.arrow.down.right"), build: staticNoise),

        // Playful
        entry("smileys", "Smileys", "Happy faces float up from the key.", "face.smiling.fill", "yellow",
              count: 4, 1...9, extra: times("rise", "Rise", "arrow.up"), build: smileys),
        entry("ghosts", "Ghosts", "Ghosts drift up and wobble away.", "moon.zzz.fill", "gray",
              count: 3, 1...7, extra: times("wobble", "Wobble", "waveform"), build: ghosts),
        entry("rockets", "Rockets", "Rockets shoot up out of the key.", "airplane", "red",
              count: 3, 1...7, extra: times("height", "Height", "arrow.up.to.line"), build: rockets),
        entry("ninjastars", "Ninja stars", "Spinning stars fly out of the key.", "star.circle.fill", "indigo",
              count: 6, 3...14, extra: times("spin", "Spin", "arrow.clockwise"), build: ninjaStars),
        entry("boomerang", "Boomerang", "Specks fly out in a curve and come back.", "arrow.uturn.left", "orange",
              count: 5, 2...12, extra: times("reach", "Reach", "arrow.up.left.and.arrow.down.right"), build: boomerang),
        entry("yoyo", "Yo-yo", "Beads drop down and bounce back up.", "arrow.up.and.down", "blue",
              count: 3, 1...6, extra: times("length", "Length", "ruler"), build: yoyo),
        entry("pinwheel", "Pinwheel", "Little pinwheels whirl around the key.", "fan.fill", "teal",
              count: 4, 2...10, extra: times("spin", "Spin", "arrow.clockwise"), build: pinwheel),
        entry("juggle", "Juggle", "Balls loop in a figure of eight over the key.", "infinity", "purple",
              count: 4, 2...8, build: juggle),
        entry("bounce", "Bouncing balls", "Balls bounce away from the key.", "basketball.fill", "orange",
              count: 5, 2...12,
              extra: EffectParam(id: "bounces", title: "Bounces", symbol: "arrow.up.and.down", range: 1...5, value: 3, step: 1, format: .number),
              build: bouncingBalls),
        entry("snake", "Snake", "A string of beads wriggles away from the key.", "scribble", "green",
              count: 8, 3...16, extra: times("wobble", "Wobble", "waveform"), build: snake),
        entry("dizzy", "Dizzy", "Stars spin round above the key.", "star.leadinghalf.filled", "yellow",
              count: 4, 2...8, build: dizzy),
        entry("zap", "Zap", "Little electric arcs crackle around the key.", "bolt.fill", "yellow",
              count: 8, 3...18, extra: times("length", "Length", "ruler"), build: zap),

        // Shapes
        entry("halo", "Halo", "A glowing ring floats above the key.", "circle.circle", "yellow",
              count: 1, 1...3, build: halo),
        entry("crown", "Crown", "A crown appears above the key and floats away.", "trophy.fill", "yellow",
              count: 1, 1...3, extra: times("rise", "Rise", "arrow.up"), build: crown),
        entry("arrows", "Arrows", "Arrows shoot up from the key.", "arrow.up.circle.fill", "green",
              count: 5, 2...12, extra: times("rise", "Rise", "arrow.up"), build: arrows),
        entry("checkmarks", "Checkmarks", "Checkmarks pop up and float away.", "checkmark.circle.fill", "green",
              count: 4, 1...10, extra: times("rise", "Rise", "arrow.up"), build: checkmarks),
        entry("suits", "Card suits", "Spades, hearts, diamonds and clubs are thrown out.", "suit.spade.fill", "red",
              count: 8, 3...18, extra: times("gravity", "Gravity", "arrow.down.to.line"), build: suits),
        entry("dice", "Dice", "Dice tumble out of the key.", "dice.fill", "indigo",
              count: 4, 1...9, extra: times("spin", "Spin", "arrow.clockwise"), build: dice),
        entry("lasers", "Lasers", "Thin beams fan out and up from the key.", "light.max", "red",
              count: 7, 3...15, extra: times("length", "Length", "ruler"), build: lasers),
    ]

    /// The catalog effect with this id.
    static func entry(_ id: String) -> EffectEntry? {
        return all.first { $0.id == id }
    }

    /// The particles of one press for every catalog effect that is on.
    static func particles(_ config: EffectsConfig, keySize: CGSize, random: @escaping (Int, Int) -> CGFloat) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for (index, item) in all.enumerated() where config.isOn(item.id) {
            let n = max(1, Int(config.setting(item, "count").rounded()))
            let context = EffectContext(w: max(keySize.width, 1), h: max(keySize.height, 1), n: n,
                                        size: CGFloat(config.setting(item, "size")), speed: config.setting(item, "speed"),
                                        extra: CGFloat(item.params.count > 3 ? config.setting(item, item.params[3].id) : 1),
                                        seed: 2000 + index * 100, rainbow: true, random: random)
            var group = item.build(context)
            EffectParticles.finish(&group, from: 0, id: item.id, config: config, size: keySize) { random(9600 + index, $0) }
            list += group
        }
        return list
    }

    // MARK: Space

    private static func comet(_ c: EffectContext) -> [EffectParticle] {
        let w = c.w
        let arc: (CGFloat) -> CGPoint = { t in
            let x: CGFloat = -w * 1.2 + w * 2.6 * t
            let y: CGFloat = w * 0.9 - w * 2.0 * t - w * 0.3 * sin(.pi * t)
            return CGPoint(x: x, y: y)
        }
        var list: [EffectParticle] = []
        let dots = max(c.n, 3)
        for k in 0..<dots {
            let along = CGFloat(k) / CGFloat(dots)
            list.append(c.speck(.dot, k == 0 ? 7 : 5 * (1 - along * 0.7), 0.7, delay: Double(k) * 0.035 * Double(c.extra),
                                from: 1, to: 0.6, peak: 1 - along * 0.75, hue: c.hue(k), path: arc))
        }
        return list
    }

    private static func meteors(_ c: EffectContext) -> [EffectParticle] {
        let w = c.w
        let angle = atan2(CGFloat(0.83), CGFloat(-0.55))
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x0 = c.between(-0.2, 1.0, i, 1) * w
            let startY = -w * 1.4
            list.append(c.speck(.streak(angle: angle), w * 0.4, 0.5 + Double(c.r(i, 2)) * 0.2, delay: Double(c.r(i, 3)) * 0.4,
                                peak: 0.9, hue: c.hue(i),
                                path: { t in
                                    let run: CGFloat = w * 2.0 * t
                                    return CGPoint(x: x0 - 0.55 * run, y: startY + 0.83 * run)
                                }))
        }
        return list
    }

    private static func galaxy(_ c: EffectContext) -> [EffectParticle] {
        let arms = max(2, Int(c.extra.rounded()))
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let arm = CGFloat(i % arms) / CGFloat(arms)
            let start: CGFloat = 2 * .pi * arm + c.r(i, 1) * 0.3
            let reach = c.w * c.between(0.8, 1.5, i, 2)
            list.append(c.speck(.dot, c.between(2.5, 4.5, i, 3), 1.0, delay: Double(i / arms) * 0.03, from: 1, to: 0.3,
                                hue: c.hue(i),
                                path: { t in
                                    let angle: CGFloat = start + 4 * t
                                    let radius: CGFloat = reach * EffectPath.easeOut(t)
                                    return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                                }))
        }
        return list
    }

    private static func nebula(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let angle = c.r(i, 1) * 2 * .pi
            let distance = c.w * c.between(0.4, 0.9, i, 2) * c.extra
            list.append(c.speck(.soft, c.w * 0.5, 1.3, delay: Double(c.r(i, 3)) * 0.2, from: 0.6, to: 1.8, peak: 0.45,
                                hue: c.hue(i), path: EffectPath.burst(angle: angle, distance: distance)))
        }
        return list
    }

    private static func twinkle(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let angle = c.r(i, 1) * 2 * .pi
            let radius = c.w * (0.45 + 0.5 * c.r(i, 2)) * c.extra
            let x = cos(angle) * radius
            let y = sin(angle) * radius * 0.8
            list.append(c.speck(.art(.sparkle), c.between(8, 14, i, 3), 0.8, delay: Double(c.r(i, 4)) * 0.4, spin: 0.6,
                                from: 0.2, to: 1.2, hue: c.hue(i), path: { _ in CGPoint(x: x, y: y) }))
        }
        return list
    }

    private static func planets(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let radius = c.w * (0.7 + 0.35 * CGFloat(i)) * c.extra
            let start = c.r(i, 1) * 2 * .pi
            list.append(c.speck(.ring, radius * 2 / c.size, 1.0, from: 1, to: 1.05, peak: 0.3, path: { _ in .zero }))
            list.append(c.speck(.dot, 5 + CGFloat(i % 3) * 2, 1.0, from: 1, to: 0.7, hue: c.hue(i),
                                path: EffectPath.orbit(center: .zero, rx: radius, ry: radius * 0.8, start: start, turns: 1)))
        }
        return list
    }

    private static func blackhole(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let start = c.r(i, 1) * 2 * .pi
            let reach = c.w * 1.4 * c.extra
            list.append(c.speck(.dot, c.between(2.5, 4.5, i, 2), 0.7, delay: Double(c.r(i, 3)) * 0.15, from: 1, to: 0.2,
                                hue: c.hue(i), path: EffectPath.spiral(start: start, from: reach, to: 0, turns: 1.2)))
        }
        return list
    }

    private static func supernova(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for ring in 0..<3 {
            list.append(c.speck(.ring, c.w * 2 * c.extra, 0.7, delay: Double(ring) * 0.12, from: 0.1, to: 1, peak: 0.8,
                                hue: c.hue(ring), path: { _ in .zero }))
        }
        for i in 0..<c.n {
            let angle = c.r(i, 1) * 2 * .pi
            let distance = c.w * c.between(0.8, 1.6, i, 2) * c.extra
            list.append(c.speck(.dot, c.between(2.5, 5, i, 3), 0.8, from: 1, to: 0.3, hue: c.hue(i),
                                path: EffectPath.burst(angle: angle, distance: distance)))
        }
        return list
    }

    // MARK: Nature

    private static func petals(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x0 = (c.r(i, 1) - 0.5) * c.w * 1.2
            list.append(c.speck(.art(.petal), c.between(10, 16, i, 2), 1.4 + Double(c.r(i, 3)) * 0.4,
                                delay: Double(c.r(i, 4)) * 0.4, spin: (c.r(i, 5) - 0.5) * 6, from: 1, to: 0.8, hue: c.hue(i),
                                path: EffectPath.fall(x: x0, top: -c.w * 0.9, bottom: c.w * 0.9, sway: 8 * c.extra,
                                                      phase: c.r(i, 6) * 6.28)))
        }
        return list
    }

    private static func leaves(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x0 = (c.r(i, 1) - 0.5) * c.w * 1.2
            list.append(c.speck(.art(.leaf), c.between(12, 18, i, 2), 1.6 + Double(c.r(i, 3)) * 0.4,
                                delay: Double(c.r(i, 4)) * 0.4, spin: (c.r(i, 5) - 0.5) * 9, from: 1, to: 0.8, hue: c.hue(i),
                                path: EffectPath.fall(x: x0, top: -c.w, bottom: c.w, sway: 16 * c.extra,
                                                      phase: c.r(i, 6) * 6.28, turns: 1)))
        }
        return list
    }

    private static func sakura(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x0 = (c.r(i, 1) - 0.5) * c.w * 0.6
            let phase = c.r(i, 2) * 6.28
            let w = c.w
            list.append(c.speck(.art(.flower), c.between(10, 15, i, 3), 1.6, delay: Double(c.r(i, 4)) * 0.4,
                                spin: 8, from: 1, to: 0.7, hue: c.hue(i),
                                path: { t in
                                    let angle: CGFloat = t * 4 * .pi + phase
                                    return CGPoint(x: x0 + cos(angle) * w * 0.25 * t, y: -w * 0.8 + w * 1.7 * t)
                                }))
        }
        return list
    }

    private static func butterflies(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x0 = (c.r(i, 1) - 0.5) * c.w * 0.5
            list.append(c.speck(.art(.butterfly), 16, 1.6, delay: Double(c.r(i, 2)) * 0.5, from: 0.7, to: 1.1,
                                path: EffectPath.rise(x: x0, height: c.w * 1.6, sway: 18 * c.extra, phase: c.r(i, 3) * 6.28, turns: 2.2)))
        }
        return list
    }

    private static func fireflies(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let radius = c.w * (0.5 + 0.5 * c.r(i, 1)) * c.extra
            let p1 = c.r(i, 2) * 6.28
            let p2 = c.r(i, 3) * 6.28
            list.append(c.speck(.ember, c.between(3, 5, i, 4), 1.8, delay: Double(c.r(i, 5)) * 0.5, from: 1, to: 0.8, hue: c.hue(i),
                                path: { t in
                                    let a: CGFloat = t * 2 * .pi * 1.3 + p1
                                    let b: CGFloat = t * 2 * .pi * 1.9 + p2
                                    return CGPoint(x: sin(a) * radius, y: sin(b) * radius * 0.8 - t * 12)
                                }))
        }
        return list
    }

    private static func splash(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let dx = (c.r(i, 1) - 0.5) * c.w * 1.1
            let dy = -c.w * c.between(0.6, 1.3, i, 2)
            list.append(c.speck(.drop, c.between(5, 9, i, 3), 0.7, delay: Double(c.r(i, 4)) * 0.1, hue: c.hue(i),
                                path: EffectPath.throwing(dx: dx, dy: dy, gravity: c.w * 3 * c.extra)))
        }
        return list
    }

    private static func dandelion(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let y0 = (c.r(i, 1) - 0.5) * c.h * 0.6
            let drift = c.w * c.between(1.0, 1.8, i, 2)
            let phase = c.r(i, 3) * 6.28
            list.append(c.speck(.art(.seed), c.between(9, 14, i, 4), 1.6, delay: Double(c.r(i, 5)) * 0.4,
                                spin: (c.r(i, 6) - 0.5) * 4, from: 1, to: 0.6, hue: c.hue(i),
                                path: { t in
                                    let angle: CGFloat = t * 2 * .pi * 2 + phase
                                    return CGPoint(x: drift * t, y: y0 - c.w * 0.5 * t + sin(angle) * 8 * c.extra)
                                }))
        }
        return list
    }

    private static func flames(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x0 = (c.r(i, 1) - 0.5) * c.w * 0.7
            list.append(c.speck(.ember, c.between(4, 8, i, 2), 0.8 + Double(c.r(i, 3)) * 0.3, delay: Double(c.r(i, 4)) * 0.3,
                                from: 1, to: 0.2, hue: c.hue(i),
                                path: EffectPath.rise(x: x0, height: c.w * c.between(0.8, 1.4, i, 5) * c.extra,
                                                      sway: 6, phase: c.r(i, 6) * 6.28, turns: 2.5)))
        }
        return list
    }

    private static func sparkler(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let angle = c.r(i, 1) * 2 * .pi
            list.append(c.speck(.streak(angle: angle), 7, 0.5 + Double(c.r(i, 2)) * 0.3, delay: Double(c.r(i, 3)) * 0.2,
                                from: 1, to: 0.5, hue: c.hue(i),
                                path: EffectPath.burst(angle: angle, distance: c.w * c.between(0.8, 1.6, i, 4), gravity: c.w * 0.5)))
        }
        return list
    }

    private static func aurora(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x0 = (CGFloat(i) / CGFloat(max(c.n - 1, 1)) - 0.5) * c.w * 1.2
            list.append(c.speck(.soft, c.w * 0.45, 1.4, delay: Double(i) * 0.1, from: 0.6, to: 1.4, peak: 0.4,
                                hue: c.hue(i),
                                path: EffectPath.rise(x: x0, height: c.w * 1.6 * c.extra, sway: 12, phase: c.r(i, 1) * 6.28, turns: 1)))
        }
        return list
    }

    // MARK: Celebration

    private static func coins(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let dx = (c.r(i, 1) - 0.5) * c.w * 1.2
            let dy = -c.w * c.between(0.9, 1.6, i, 2)
            list.append(c.speck(.art(.coin), c.between(11, 16, i, 3), 1.0, delay: Double(c.r(i, 4)) * 0.15,
                                spin: (c.r(i, 5) - 0.5) * 14, hue: c.hue(i),
                                path: EffectPath.throwing(dx: dx, dy: dy, gravity: c.w * 3.2 * c.extra)))
        }
        return list
    }

    private static func gems(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let angle = c.r(i, 1) * 2 * .pi
            list.append(c.speck(.art(.gem), c.between(8, 14, i, 2), 0.9, spin: (c.r(i, 3) - 0.5) * 6, from: 1, to: 0.4,
                                hue: c.hue(i),
                                path: EffectPath.burst(angle: angle, distance: c.w * c.between(0.7, 1.4, i, 4), gravity: c.w * 0.6)))
        }
        return list
    }

    private static func balloons(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x0 = (c.r(i, 1) - 0.5) * c.w * 0.9
            list.append(c.speck(.art(.balloon), 18, 1.8, delay: Double(c.r(i, 2)) * 0.4, from: 0.8, to: 1.1,
                                path: EffectPath.rise(x: x0, height: c.w * 2 * c.extra, sway: 10, phase: c.r(i, 3) * 6.28, turns: 1)))
        }
        return list
    }

    private static func streamers(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let dx = (c.r(i, 1) - 0.5) * c.w * 1.6
            let dy = -c.w * c.between(0.9, 1.7, i, 2)
            list.append(c.speck(.bar, c.between(9, 14, i, 3), 1.2, delay: Double(c.r(i, 4)) * 0.1, spin: (c.r(i, 5) - 0.5) * 16,
                                hue: c.hue(i) ?? c.r(i, 6),
                                path: EffectPath.throwing(dx: dx, dy: dy, gravity: c.w * 2.6 * c.extra)))
        }
        return list
    }

    private static func disco(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x = (c.r(i, 1) - 0.5) * c.w * 1.6 * c.extra
            let y = (c.r(i, 2) - 0.5) * c.h * 1.6 * c.extra
            list.append(c.speck(.square, c.between(6, 11, i, 3), 0.35, delay: Double(c.r(i, 4)) * 0.4, from: 0.4, to: 1.3,
                                hue: c.hue(i) ?? c.r(i, 5), path: { _ in CGPoint(x: x, y: y) }))
        }
        return list
    }

    private static func glitter(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x0 = (c.r(i, 1) - 0.5) * c.w * 1.1
            let y0 = (c.r(i, 2) - 0.5) * c.h
            list.append(c.speck(.dot, c.between(1.5, 3, i, 3), 1.2, delay: Double(c.r(i, 4)) * 0.4, from: 1, to: 0.3,
                                hue: c.hue(i), path: { t in CGPoint(x: x0, y: y0 + c.w * 0.6 * t) }))
        }
        return list
    }

    private static func pixels(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let dx = (c.r(i, 1) - 0.5) * c.w * 1.4
            let dy = -c.w * c.between(0.3, 1.0, i, 2)
            list.append(c.speck(.square, c.between(4, 7, i, 3), 0.9, hue: c.hue(i),
                                path: EffectPath.throwing(dx: dx, dy: dy, gravity: c.w * 3)))
        }
        return list
    }

    private static func rainbowBurst(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let angle = 2 * CGFloat.pi * CGFloat(i) / CGFloat(c.n)
            list.append(c.speck(.streak(angle: angle), c.w * 0.3, 0.5, from: 1, to: 0.5, peak: 0.95, hue: CGFloat(i) / CGFloat(c.n),
                                path: EffectPath.burst(angle: angle, distance: c.w * 1.3 * c.extra)))
        }
        return list
    }

    // MARK: Tech

    private static func matrix(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x0 = (c.r(i, 1) - 0.5) * c.w * 1.2
            list.append(c.speck(.art(.bit(i % 2 == 1)), c.between(9, 13, i, 2), 0.9, delay: Double(c.r(i, 3)) * 0.4,
                                peak: 0.9, hue: c.hue(i), path: { t in CGPoint(x: x0, y: -c.w * 1.2 + c.w * 2.0 * t) }))
        }
        return list
    }

    private static func sonar(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            list.append(c.speck(.ring, c.w * 0.6, 0.8, delay: Double(i) * 0.18, from: 0.2, to: 3 * c.extra, peak: 0.85,
                                hue: c.hue(i), path: { _ in .zero }))
        }
        return list
    }

    private static func circuit(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            var points: [CGPoint] = [.zero]
            var x: CGFloat = 0
            var y: CGFloat = 0
            for leg in 0..<4 {
                let run = c.w * c.between(0.3, 0.7, i, 10 + leg) * c.extra
                let sign: CGFloat = c.r(i, 20 + leg) > 0.5 ? 1 : -1
                if leg % 2 == 0 { x += run * sign } else { y += run * sign }
                points.append(CGPoint(x: x, y: y))
            }
            list.append(c.speck(.dot, 3.5, 0.9, delay: Double(c.r(i, 1)) * 0.3, from: 1, to: 0.6, hue: c.hue(i),
                                path: EffectPath.walk(points)))
        }
        return list
    }

    private static func hologram(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            list.append(c.speck(.streak(angle: 0), c.w * 0.9, 0.5, delay: Double(i) * 0.08, peak: 0.7, hue: c.hue(i),
                                path: { t in CGPoint(x: 0, y: -c.h * 0.8 + c.h * 1.6 * t) }))
        }
        return list
    }

    private static func staticNoise(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x = (c.r(i, 1) - 0.5) * c.w * 1.6 * c.extra
            let y = (c.r(i, 2) - 0.5) * c.h * 1.6 * c.extra
            list.append(c.speck(.square, c.between(2, 4, i, 3), 0.25, delay: Double(c.r(i, 4)) * 0.4, hue: c.hue(i),
                                path: { _ in CGPoint(x: x, y: y) }))
        }
        return list
    }

    // MARK: Playful

    private static func smileys(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x0 = (c.r(i, 1) - 0.5) * c.w * 0.8
            list.append(c.speck(.art(.smiley), 18, 1.3, delay: Double(c.r(i, 2)) * 0.4, from: 0.6, to: 1.2,
                                path: EffectPath.rise(x: x0, height: c.w * 1.5 * c.extra, sway: 8, phase: c.r(i, 3) * 6.28)))
        }
        return list
    }

    private static func ghosts(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x0 = (c.r(i, 1) - 0.5) * c.w * 0.8
            list.append(c.speck(.art(.ghost), 18, 1.6, delay: Double(c.r(i, 2)) * 0.4, from: 0.7, to: 1.2, peak: 0.9,
                                path: EffectPath.rise(x: x0, height: c.w * 1.6, sway: 16 * c.extra, phase: c.r(i, 3) * 6.28, turns: 1.6)))
        }
        return list
    }

    private static func rockets(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x0 = (c.r(i, 1) - 0.5) * c.w * 0.9
            let lean = (c.r(i, 2) - 0.5) * c.w * 0.4
            let height = c.w * 2.2 * c.extra
            list.append(c.speck(.art(.rocket), 18, 0.8, delay: Double(c.r(i, 3)) * 0.3, from: 1, to: 0.8,
                                path: { t in CGPoint(x: x0 + lean * t, y: -height * t * t) }))
        }
        return list
    }

    private static func ninjaStars(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let angle = 2 * CGFloat.pi * CGFloat(i) / CGFloat(c.n) + c.r(i, 1) * 0.3
            list.append(c.speck(.art(.ninja), c.between(11, 16, i, 2), 0.7, spin: 14 * c.extra, from: 1, to: 0.6,
                                hue: c.hue(i), path: EffectPath.burst(angle: angle, distance: c.w * 1.5)))
        }
        return list
    }

    private static func boomerang(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let angle = c.r(i, 1) * 2 * .pi
            let reach = c.w * c.between(1.0, 1.6, i, 2) * c.extra
            list.append(c.speck(.dot, 4.5, 1.0, delay: Double(c.r(i, 3)) * 0.2, from: 1, to: 1, hue: c.hue(i),
                                path: { t in
                                    let out: CGFloat = sin(.pi * t) * reach
                                    let bend: CGFloat = sin(2 * .pi * t) * reach * 0.35
                                    let dx: CGFloat = cos(angle) * out - sin(angle) * bend
                                    let dy: CGFloat = sin(angle) * out + cos(angle) * bend
                                    return CGPoint(x: dx, y: dy)
                                }))
        }
        return list
    }

    private static func yoyo(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x = (CGFloat(i) - CGFloat(c.n - 1) / 2) * c.w * 0.35
            let length = c.w * c.between(0.8, 1.4, i, 1) * c.extra
            list.append(c.speck(.dot, 6, 0.9, delay: Double(i) * 0.1, hue: c.hue(i),
                                path: { t in CGPoint(x: x, y: length * sin(.pi * t)) }))
        }
        return list
    }

    private static func pinwheel(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let start = 2 * CGFloat.pi * CGFloat(i) / CGFloat(c.n)
            list.append(c.speck(.art(.pinwheel), 12, 1.0, spin: 12 * c.extra, from: 1, to: 0.6, hue: c.hue(i),
                                path: EffectPath.orbit(center: .zero, rx: c.w * 0.65, ry: c.h * 0.8, start: start, turns: 1)))
        }
        return list
    }

    private static func juggle(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let start = 2 * CGFloat.pi * CGFloat(i) / CGFloat(c.n)
            let a = c.w * 0.75
            let b = c.h * 0.9
            list.append(c.speck(.dot, 5, 1.4, from: 1, to: 0.8, hue: c.hue(i),
                                path: { t in
                                    let angle: CGFloat = start + 2 * .pi * 1.5 * t
                                    return CGPoint(x: sin(angle) * a, y: -c.h * 0.7 + sin(angle) * cos(angle) * b)
                                }))
        }
        return list
    }

    private static func bouncingBalls(_ c: EffectContext) -> [EffectParticle] {
        let bounces = max(1, Int(c.extra.rounded()))
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let dx = (c.r(i, 1) - 0.5) * c.w * 2.2
            let top = c.w * c.between(0.5, 0.9, i, 2)
            list.append(c.speck(.dot, c.between(5, 8, i, 3), 1.2, delay: Double(c.r(i, 4)) * 0.2, from: 1, to: 0.7, hue: c.hue(i),
                                path: { t in
                                    let hop: CGFloat = abs(sin(.pi * CGFloat(bounces) * t)) * (1 - t)
                                    return CGPoint(x: dx * t, y: -top * hop + c.h * 0.4)
                                }))
        }
        return list
    }

    private static func snake(_ c: EffectContext) -> [EffectParticle] {
        let angle = -CGFloat.pi / 2 + 0.5
        var list: [EffectParticle] = []
        for k in 0..<max(c.n, 3) {
            let wave = 14 * c.extra
            list.append(c.speck(.dot, 5 - CGFloat(k) * 0.25, 1.2, delay: Double(k) * 0.06, from: 1, to: 0.4,
                                peak: 1 - CGFloat(k) * 0.05, hue: c.hue(k),
                                path: { t in
                                    let along: CGFloat = c.w * 1.8 * t
                                    let side: CGFloat = sin(t * 2 * .pi * 2.5) * wave
                                    let dx: CGFloat = cos(angle) * along - sin(angle) * side
                                    let dy: CGFloat = sin(angle) * along + cos(angle) * side
                                    return CGPoint(x: dx, y: dy)
                                }))
        }
        return list
    }

    private static func dizzy(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let start = 2 * CGFloat.pi * CGFloat(i) / CGFloat(c.n)
            list.append(c.speck(.art(.star), 10, 1.2, spin: 2, from: 1, to: 0.8, hue: c.hue(i),
                                path: EffectPath.orbit(center: CGPoint(x: 0, y: -c.h * 0.9), rx: c.w * 0.45, ry: c.h * 0.16,
                                                       start: start, turns: 2)))
        }
        return list
    }

    private static func zap(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let angle = c.r(i, 1) * 2 * .pi
            let radius = c.w * c.between(0.5, 0.9, i, 2)
            let x = cos(angle) * radius
            let y = sin(angle) * radius * 0.8
            let bolt = angle + (c.r(i, 3) - 0.5) * 1.6
            list.append(c.speck(.streak(angle: bolt), c.w * 0.3 * c.extra, 0.2, delay: Double(c.r(i, 4)) * 0.3,
                                from: 0.6, to: 1.2, hue: c.hue(i), path: { _ in CGPoint(x: x, y: y) }))
        }
        return list
    }

    // MARK: Shapes

    private static func halo(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            list.append(c.speck(.ring, c.w * 0.7, 0.8, delay: Double(i) * 0.15, from: 0.5, to: 1, peak: 0.9, hue: c.hue(i),
                                path: { t in CGPoint(x: 0, y: -c.h * 0.8 - 10 * t) }))
        }
        return list
    }

    private static func crown(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x = (CGFloat(i) - CGFloat(c.n - 1) / 2) * c.w * 0.5
            list.append(c.speck(.art(.crown), 20, 1.0, delay: Double(i) * 0.1, from: 0.5, to: 1.1, hue: c.hue(i),
                                path: { t in CGPoint(x: x, y: -c.h * 0.8 - c.w * 0.6 * c.extra * t) }))
        }
        return list
    }

    private static func arrows(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x = (c.r(i, 1) - 0.5) * c.w * 0.9
            list.append(c.speck(.art(.arrow), c.between(12, 18, i, 2), 0.9, delay: Double(c.r(i, 3)) * 0.3, hue: c.hue(i),
                                path: { t in CGPoint(x: x, y: -c.w * 1.6 * c.extra * EffectPath.easeOut(t)) }))
        }
        return list
    }

    private static func checkmarks(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let x = (c.r(i, 1) - 0.5) * c.w * 0.9
            list.append(c.speck(.art(.check), c.between(13, 19, i, 2), 1.0, delay: Double(c.r(i, 3)) * 0.3, from: 0.3, to: 1.1,
                                hue: c.hue(i), path: { t in CGPoint(x: x, y: -c.w * 1.3 * c.extra * EffectPath.easeOut(t)) }))
        }
        return list
    }

    private static func suits(_ c: EffectContext) -> [EffectParticle] {
        let suits: [EffectArt] = [.spade, .heart, .diamond, .club]
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let dx = (c.r(i, 1) - 0.5) * c.w * 1.6
            let dy = -c.w * c.between(0.8, 1.5, i, 2)
            list.append(c.speck(.art(suits[i % 4]), c.between(11, 16, i, 3), 1.1, delay: Double(c.r(i, 4)) * 0.15,
                                spin: (c.r(i, 5) - 0.5) * 8, hue: c.hue(i),
                                path: EffectPath.throwing(dx: dx, dy: dy, gravity: c.w * 3 * c.extra)))
        }
        return list
    }

    private static func dice(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let face = Int(c.r(i, 1) * 6) % 6
            let dx = (c.r(i, 2) - 0.5) * c.w * 1.6
            let dy = -c.w * c.between(0.7, 1.3, i, 3)
            list.append(c.speck(.art(.die(face)), c.between(15, 21, i, 4), 1.1, delay: Double(c.r(i, 5)) * 0.15,
                                spin: 10 * c.extra * (c.r(i, 6) > 0.5 ? 1 : -1), hue: c.hue(i),
                                path: EffectPath.throwing(dx: dx, dy: dy, gravity: c.w * 3)))
        }
        return list
    }

    private static func lasers(_ c: EffectContext) -> [EffectParticle] {
        var list: [EffectParticle] = []
        for i in 0..<c.n {
            let fan: CGFloat = c.n > 1 ? CGFloat(i) / CGFloat(c.n - 1) - 0.5 : 0
            let angle = -CGFloat.pi / 2 + fan * 1.6
            list.append(c.speck(.streak(angle: angle), c.w * 0.8 * c.extra, 0.35, delay: Double(i) * 0.02, peak: 0.95,
                                hue: c.hue(i), path: EffectPath.burst(angle: angle, distance: c.w * 1.8)))
        }
        return list
    }
}
