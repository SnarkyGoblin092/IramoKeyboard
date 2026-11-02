import CoreGraphics

/// The shape of a lightning bolt, drawn by both the keyboard (KeyView) and the Effects screen's keyboard (EffectsView).
enum EffectBolt {
    /// A bolt that strikes down onto the middle of the key (0, 0) from `length` above it: the main stroke and a few
    /// forks, as points offset from the key's middle. Every stroke is broken up again and again, so it jags like the
    /// real thing. `random(index, salt)` gives numbers in 0..<1.
    static func make(length: CGFloat, width: CGFloat, random: @escaping (Int, Int) -> CGFloat) -> (main: [CGPoint], forks: [[CGPoint]]) {
        var counter = 0
        func next() -> CGFloat {
            counter += 1
            return random(counter, 7)
        }

        /// A line from `a` to `b`, its middle pushed sideways, then each half the same again, half as far.
        func jagged(from a: CGPoint, to b: CGPoint, roughness: CGFloat, levels: Int) -> [CGPoint] {
            var points: [CGPoint] = [a, b]
            var amount = roughness
            for _ in 0..<levels {
                var refined: [CGPoint] = []
                for index in 0..<(points.count - 1) {
                    let p = points[index]
                    let q = points[index + 1]
                    let dx = q.x - p.x
                    let dy = q.y - p.y
                    let span = max(hypot(dx, dy), 0.001)
                    let push = (next() - 0.5) * 2 * amount
                    refined.append(p)
                    refined.append(CGPoint(x: (p.x + q.x) / 2 - dy / span * push, y: (p.y + q.y) / 2 + dx / span * push))
                }
                refined.append(points[points.count - 1])
                points = refined
                amount /= 2
            }
            return points
        }

        let top = CGPoint(x: (next() - 0.5) * width * 0.6, y: -length)
        let main = jagged(from: top, to: .zero, roughness: length * 0.22, levels: 4)
        var forks: [[CGPoint]] = []
        let count = 2 + Int(next() * 2)
        for _ in 0..<count {
            // Forks leave the upper part of the bolt and go down and outwards.
            let index = 3 + Int(next() * 8)
            let origin = main[min(index, main.count - 1)]
            let side: CGFloat = next() > 0.5 ? 1 : -1
            let reach = length * (0.25 + next() * 0.2)
            let end = CGPoint(x: origin.x + side * reach * 0.7, y: origin.y + reach * 0.7)
            forks.append(jagged(from: origin, to: end, roughness: reach * 0.25, levels: 3))
        }
        return (main, forks)
    }
}
