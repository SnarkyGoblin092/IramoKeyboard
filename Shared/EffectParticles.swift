import CoreGraphics

/// One speck of a particle effect, described once and drawn twice: by the keyboard (Core Animation, KeyView) and by
/// the Effects screen's keyboard (SwiftUI, EffectsView), so both play the same thing.
struct EffectParticle {
    enum Shape {
        /// A drawn picture (a heart, a star, a note...): see EffectArt.
        case art(EffectArt)
        case dot
        /// A thin line pointing along `angle`.
        case streak(angle: CGFloat)
        /// A falling streak of rain: thin, fading out towards its tail.
        case drop
        /// A soft puff.
        case soft
        /// A dot that glows.
        case ember
        /// A circle drawn as a line, `size` across.
        case ring
        /// A square, `size` on each side.
        case square
        /// A small bar, `size` long.
        case bar
    }

    var shape: Shape
    /// Its size in points (the line's length for a streak, the height of a drop).
    var size: CGFloat
    var duration: Double
    var delay: Double = 0
    /// How far it turns over its flight, in radians.
    var spin: CGFloat = 0
    var scaleFrom: CGFloat = 1
    var scaleTo: CGFloat = 1
    /// The most opaque it gets (it fades in at the start and out at the end).
    var peak: CGFloat = 1
    /// A hue of its own (the rainbow colour); nil takes the press's colour.
    var hue: CGFloat? = nil
    /// How far it is turned (radians, clockwise) while it flies, for the shapes that point somewhere (rain, rockets,
    /// arrows): set by the direction setting. Spin comes on top of it.
    var tilt: CGFloat = 0
    /// Where it is, as an offset from the middle of the key, for `t` from 0 (start) to 1 (end).
    var path: (CGFloat) -> CGPoint

    /// Whether it points somewhere, so that it is turned with the direction it flies in.
    var isOriented: Bool {
        switch shape {
        case .drop: return true
        case .art(let art): return art.isOriented
        default: return false
        }
    }
}

enum EffectParticles {
    /// Everything the particle effects that are on play for one press, on a key of `keySize`. `random(index, salt)`
    /// is a number in 0..<1 (really random on the keyboard, steady in the preview so it can be redrawn).
    static func make(_ config: EffectsConfig, keySize: CGSize, random: @escaping (Int, Int) -> CGFloat) -> [EffectParticle] {
        let w = max(keySize.width, 1)
        let h = max(keySize.height, 1)
        let rainbow = config.colorMode == "rainbow"
        var list: [EffectParticle] = []
        // The direction setting turns each effect in turn (it needs to know where one ends and the next begins).
        var groupStart = 0
        var groupIndex = 0
        func flush() {
            defer { groupStart = list.count; groupIndex += 1 }
            guard config.direction != "auto", groupStart < list.count,
                  let target = EffectDirection.target(config.direction, random: { random(9000 + groupIndex, 1) }) else { return }
            redirect(&list, from: groupStart, to: target, scale: w)
        }

        func count(_ value: Double) -> Int { return max(1, Int(value.rounded())) }
        func easeOut(_ t: CGFloat) -> CGFloat { return 1 - (1 - t) * (1 - t) }
        func hue(_ base: Int, _ i: Int) -> CGFloat? { return rainbow ? random(base + i, 99) : nil }

        flush()
        if config.hearts {
            for i in 0..<count(config.heartCount) {
                let r = { (salt: Int) in random(100 + i, salt) }
                let x0 = (r(4) - 0.5) * w * 0.6
                let sway = 4 + r(5) * 6
                let phase = r(7) * 2 * .pi
                let rise = w * (1.2 + r(6) * 0.8)
                list.append(EffectParticle(shape: .art(.heart), size: 12 + r(1) * 8, duration: 0.9 + Double(r(3)) * 0.5,
                                           delay: Double(r(2)) * 0.3, spin: (r(8) - 0.5) * 0.8, scaleFrom: 0.6, scaleTo: 1.1,
                                           hue: hue(100, i),
                                           path: { t in
                                               let angle: CGFloat = t * 2 * .pi * 1.2 + phase
                                               return CGPoint(x: x0 + sin(angle) * sway, y: -rise * t)
                                           }))
            }
        }
        flush()
        if config.stars {
            let n = count(config.starCount)
            for i in 0..<n {
                let r = { (salt: Int) in random(200 + i, salt) }
                let angle = 2 * .pi * CGFloat(i) / CGFloat(n) + r(1) * 0.5
                let distance = w * (0.7 + r(2) * 0.8)
                list.append(EffectParticle(shape: .art(.star), size: 9 + r(3) * 6, duration: 0.7, spin: (r(4) - 0.5) * 6,
                                           scaleFrom: 1, scaleTo: 0.3, hue: hue(200, i),
                                           path: { t in
                                               let out = easeOut(t)
                                               let dx: CGFloat = cos(angle) * distance * out
                                               let dy: CGFloat = sin(angle) * distance * out
                                               return CGPoint(x: dx, y: dy)
                                           }))
            }
        }
        flush()
        if config.snow {
            for i in 0..<count(config.snowCount) {
                let r = { (salt: Int) in random(300 + i, salt) }
                let x0 = (r(1) - 0.5) * w * 1.2
                let phase = r(2) * 2 * .pi
                list.append(EffectParticle(shape: .art(.snowflake), size: 9 + r(5) * 6, duration: 1.2 + Double(r(3)) * 0.4,
                                           delay: Double(r(4)) * 0.35, spin: 1.5, scaleFrom: 1, scaleTo: 0.8, hue: hue(300, i),
                                           path: { t in
                                               let angle: CGFloat = t * 2 * .pi * 1.5 + phase
                                               return CGPoint(x: x0 + sin(angle) * 6, y: -w * 0.9 + w * 1.7 * t)
                                           }))
            }
        }
        flush()
        if config.notes {
            for i in 0..<count(config.noteCount) {
                let r = { (salt: Int) in random(400 + i, salt) }
                let x0 = (r(1) - 0.5) * w * 0.5
                let drift = (r(2) - 0.3) * w * 0.9
                let rise = w * (1 + r(3) * 0.6)
                list.append(EffectParticle(shape: .art(.note), size: 13 + r(4) * 6,
                                           duration: 1.0, delay: Double(r(5)) * 0.3, spin: (r(6) - 0.5) * 0.6,
                                           scaleFrom: 0.7, scaleTo: 1, hue: hue(400, i),
                                           path: { t in
                                               let angle: CGFloat = t * 4 * .pi
                                               return CGPoint(x: x0 + drift * t + sin(angle) * 4, y: -rise * t)
                                           }))
            }
        }
        flush()
        if config.fireworks {
            for i in 0..<count(config.fireworkCount) {
                let r = { (salt: Int) in random(500 + i, salt) }
                let angle = r(1) * 2 * .pi
                let reach = w * (0.9 + r(2) * 1.1)
                list.append(EffectParticle(shape: .dot, size: 2.5 + r(3) * 2, duration: 0.8 + Double(r(4)) * 0.3,
                                           scaleFrom: 1, scaleTo: 0.5, hue: hue(500, i),
                                           path: { t in
                                               let out = easeOut(t)
                                               let dx: CGFloat = cos(angle) * reach * out
                                               let dy: CGFloat = sin(angle) * reach * out + w * 0.9 * t * t
                                               return CGPoint(x: dx, y: dy)
                                           }))
            }
        }
        flush()
        if config.starburst {
            let n = count(config.rayCount)
            for i in 0..<n {
                let angle = 2 * .pi * CGFloat(i) / CGFloat(n)
                list.append(EffectParticle(shape: .streak(angle: angle), size: w * 0.35, duration: 0.45,
                                           scaleFrom: 1, scaleTo: 0.4, peak: 0.9, hue: hue(600, i),
                                           path: { t in
                                               let distance = w * (0.35 + 0.95 * easeOut(t))
                                               return CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
                                           }))
            }
        }
        flush()
        if config.rain {
            for i in 0..<count(config.rainCount) {
                let r = { (salt: Int) in random(700 + i, salt) }
                let x0 = (r(1) - 0.5) * w * 1.1
                let top = -w * 0.6
                let bottom = w * 0.7
                let delay = Double(r(4)) * 0.3
                let fall = 0.42 + Double(r(3)) * 0.2
                list.append(EffectParticle(shape: .drop, size: 12 + r(2) * 9, duration: fall, delay: delay, peak: 0.85,
                                           hue: hue(700, i),
                                           path: { t in CGPoint(x: x0, y: top + (bottom - top) * t) }))
                list.append(EffectParticle(shape: .ring, size: 7, duration: 0.32, delay: delay + fall * 0.9,
                                           scaleFrom: 0.3, scaleTo: 1.7, peak: 0.5, hue: hue(700, i),
                                           path: { _ in CGPoint(x: x0, y: bottom) }))
            }
        }
        flush()
        if config.embers {
            for i in 0..<count(config.emberCount) {
                let r = { (salt: Int) in random(800 + i, salt) }
                let x0 = (r(1) - 0.5) * w * 0.8
                let phase = r(2) * 2 * .pi
                let rise = w * (0.8 + r(3) * 0.6)
                list.append(EffectParticle(shape: .ember, size: 2.5 + r(4) * 2, duration: 1.0 + Double(r(5)) * 0.6,
                                           delay: Double(r(6)) * 0.3, scaleFrom: 1, scaleTo: 0.3, hue: hue(800, i),
                                           path: { t in
                                               let angle: CGFloat = t * 4 * .pi + phase
                                               return CGPoint(x: x0 + sin(angle) * 5, y: -rise * t)
                                           }))
            }
        }
        flush()
        if config.smoke {
            for i in 0..<count(config.smokeCount) {
                let r = { (salt: Int) in random(900 + i, salt) }
                let x0 = (r(1) - 0.5) * w * 0.3
                let drift = (r(2) - 0.5) * w * 0.3
                list.append(EffectParticle(shape: .soft, size: w * 0.35, duration: 1.1, delay: Double(i) * 0.12,
                                           scaleFrom: 0.5, scaleTo: 2.2, peak: 0.5, hue: hue(900, i),
                                           path: { t in CGPoint(x: x0 + drift * t, y: -w * 0.9 * t) }))
            }
        }
        flush()
        if config.orbit {
            let n = count(config.orbitCount)
            for i in 0..<n {
                let start = 2 * .pi * CGFloat(i) / CGFloat(n)
                list.append(EffectParticle(shape: .dot, size: 4, duration: 0.9, scaleFrom: 1, scaleTo: 0.4, hue: hue(1000, i),
                                           path: { t in
                                               let angle: CGFloat = start + 2.6 * .pi * t
                                               return CGPoint(x: cos(angle) * w * 0.62, y: sin(angle) * h * 0.65)
                                           }))
            }
        }
        flush()
        if config.spiral {
            let n = count(config.spiralCount)
            for i in 0..<n {
                let r = { (salt: Int) in random(1100 + i, salt) }
                let start = 2 * .pi * CGFloat(i) / CGFloat(n)
                list.append(EffectParticle(shape: .dot, size: 3, duration: 0.8, delay: Double(r(1)) * 0.1,
                                           scaleFrom: 1, scaleTo: 0.4, hue: hue(1100, i),
                                           path: { t in
                                               let angle: CGFloat = start + 3 * .pi * t
                                               let radius = w * 1.1 * easeOut(t)
                                               return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                                           }))
            }
        }
        flush()
        list += EffectCatalog.particles(config, keySize: keySize, random: random)
        return list
    }
}

extension EffectParticles {
    /// Turns the particles `list[from...]` (one effect) so that the way they mainly go points at `target` (see
    /// EffectDirection). Effects that spread evenly in every direction have no way of their own and stay as they are.
    static func redirect(_ list: inout [EffectParticle], from start: Int, to target: CGFloat, scale: CGFloat) {
        var sum = CGPoint.zero
        var heads = 0
        for index in start..<list.count {
            if let head = EffectDirection.heading(list[index].path, scale: scale) {
                sum.x += head.x
                sum.y += head.y
                heads += 1
            }
        }
        guard heads > 0, hypot(sum.x, sum.y) > scale * 0.1 * CGFloat(heads) else { return }
        let natural = atan2(sum.x, -sum.y)
        let turn = target - natural
        for index in start..<list.count {
            let old = list[index].path
            list[index].path = { t in EffectDirection.turn(old(t), by: turn) }
            if list[index].isOriented { list[index].tilt += turn }
            if case .streak(let angle) = list[index].shape { list[index].shape = .streak(angle: angle + turn) }
        }
    }
}
