import UIKit

/// The swipe trail, drawn the same way on the keyboard, in the Gestures preview and on the welcome page: the finger's
/// points become one smooth curve, drawn as a ribbon that thins and fades smoothly towards its tail.
enum TrailGeometry {
    /// The points as a dense, smooth curve (a Catmull-Rom spline through them, a point about every `spacing`).
    /// `soften` rounds off a noisy path first (the finger's own points); sparse control points need none.
    static func curve(_ input: [CGPoint], spacing: CGFloat = 2, soften: Int = 0) -> [CGPoint] {
        guard input.count > 2 else {
            guard input.count == 2 else { return input }
            return line(input[0], input[1], spacing: spacing)
        }
        var points = input
        for _ in 0..<max(0, soften) where points.count > 2 {
            var next = points
            for index in 1..<(points.count - 1) {
                next[index] = CGPoint(x: (points[index - 1].x + 2 * points[index].x + points[index + 1].x) / 4,
                                      y: (points[index - 1].y + 2 * points[index].y + points[index + 1].y) / 4)
            }
            points = next
        }
        var result = [points[0]]
        for index in 0..<(points.count - 1) {
            let p0 = points[max(0, index - 1)], p1 = points[index], p2 = points[index + 1]
            let p3 = points[min(points.count - 1, index + 2)]
            let steps = max(1, Int((hypot(p2.x - p1.x, p2.y - p1.y) / spacing).rounded(.up)))
            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                let t2 = t * t, t3 = t2 * t
                func axis(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
                    return 0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (3 * b - a - 3 * c + d) * t3)
                }
                result.append(CGPoint(x: axis(p0.x, p1.x, p2.x, p3.x), y: axis(p0.y, p1.y, p2.y, p3.y)))
            }
        }
        return result
    }

    private static func line(_ a: CGPoint, _ b: CGPoint, spacing: CGFloat) -> [CGPoint] {
        let steps = max(1, Int((hypot(b.x - a.x, b.y - a.y) / spacing).rounded(.up)))
        return (0...steps).map { step in
            let t = CGFloat(step) / CGFloat(steps)
            return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
    }

    /// Draws the trail. `points` run from the tail to the finger. Styles: "fade" (the default look), "solid",
    /// "dotted" and "rainbow". `opacity` is the head's opacity; `hueShift` moves the rainbow along.
    static func draw(in ctx: CGContext, points: [CGPoint], width: CGFloat, style: String, color: UIColor,
                     opacity: CGFloat, hueShift: CGFloat = 0, soften: Int = 0) {
        let dense = curve(points, soften: soften)
        guard let head = dense.last else { return }
        let solid = style == "solid"
        let count = dense.count

        // How far along the trail each point is: 0 at the tail, 1 at the finger.
        var along = [CGFloat](repeating: 1, count: count)
        var total: CGFloat = 0
        var travelled = [CGFloat](repeating: 0, count: count)
        for index in 1..<max(1, count) {
            total += hypot(dense[index].x - dense[index - 1].x, dense[index].y - dense[index - 1].y)
            travelled[index] = total
        }
        if total > 0 { for index in 0..<count { along[index] = travelled[index] / total } }

        func alpha(_ t: CGFloat) -> CGFloat { return solid ? opacity : opacity * pow(max(0, t), 1.7) }
        func shade(_ t: CGFloat) -> UIColor {
            let a = alpha(t)
            if style == "rainbow" {
                let hue = (t + hueShift).truncatingRemainder(dividingBy: 1)
                return UIColor(hue: hue, saturation: 0.8, brightness: 1, alpha: a)
            }
            return color.withAlphaComponent(a)
        }

        if count == 1 {
            ctx.setFillColor(shade(1).cgColor)
            ctx.fillEllipse(in: CGRect(x: head.x - width / 2, y: head.y - width / 2, width: width, height: width))
            return
        }

        if style == "dotted" {
            let gap = width * 1.9
            var next: CGFloat = 0
            for index in 0..<count where travelled[index] >= next {
                next = travelled[index] + gap
                let point = dense[index]
                ctx.setFillColor(shade(along[index]).cgColor)
                ctx.fillEllipse(in: CGRect(x: point.x - width / 2, y: point.y - width / 2, width: width, height: width))
            }
            return
        }

        // The ribbon: both edges of the line, each point's normal taken from its neighbours.
        var left = [CGPoint](), right = [CGPoint](), leftOut = [CGPoint](), rightOut = [CGPoint]()
        var tangent = CGPoint(x: 1, y: 0)
        let bleed: CGFloat = 1.5
        for index in 0..<count {
            let a = dense[max(0, index - 1)], b = dense[min(count - 1, index + 1)]
            let length = hypot(b.x - a.x, b.y - a.y)
            if length > 1e-6 { tangent = CGPoint(x: (b.x - a.x) / length, y: (b.y - a.y) / length) }
            let normal = CGPoint(x: -tangent.y, y: tangent.x)
            let half = width * (solid ? 1 : 0.25 + 0.75 * along[index]) / 2
            let p = dense[index]
            left.append(CGPoint(x: p.x + normal.x * half, y: p.y + normal.y * half))
            right.append(CGPoint(x: p.x - normal.x * half, y: p.y - normal.y * half))
            leftOut.append(CGPoint(x: p.x + normal.x * (half + bleed), y: p.y + normal.y * (half + bleed)))
            rightOut.append(CGPoint(x: p.x - normal.x * (half + bleed), y: p.y - normal.y * (half + bleed)))
        }

        ctx.saveGState()
        // The outline (smooth edges, a rounded end at the finger) clips the fills.
        let outline = CGMutablePath()
        outline.move(to: left[0])
        for point in left.dropFirst() { outline.addLine(to: point) }
        let headHalf = width / 2
        let heading = atan2(tangent.y, tangent.x)
        for step in 1..<8 {
            let angle = heading + .pi / 2 - .pi * CGFloat(step) / 8
            outline.addLine(to: CGPoint(x: head.x + cos(angle) * headHalf, y: head.y + sin(angle) * headHalf))
        }
        for point in right.reversed() { outline.addLine(to: point) }
        outline.closeSubpath()
        ctx.addPath(outline)
        ctx.clip()

        // The fills are cut at the normals, so neighbours share their edges exactly: no gaps, no overlaps.
        ctx.setShouldAntialias(false)
        for index in 0..<(count - 1) {
            let t = (along[index] + along[index + 1]) / 2
            guard alpha(t) > 0.002 else { continue }
            let quad = CGMutablePath()
            quad.move(to: leftOut[index])
            quad.addLine(to: leftOut[index + 1])
            quad.addLine(to: rightOut[index + 1])
            quad.addLine(to: rightOut[index])
            quad.closeSubpath()
            ctx.setFillColor(shade(t).cgColor)
            ctx.addPath(quad)
            ctx.fillPath()
        }
        // The rounded end beyond the last point.
        let reach = width / 2 + 2
        let last = count - 1
        let cap = CGMutablePath()
        cap.move(to: leftOut[last])
        cap.addLine(to: CGPoint(x: leftOut[last].x + tangent.x * reach, y: leftOut[last].y + tangent.y * reach))
        cap.addLine(to: CGPoint(x: rightOut[last].x + tangent.x * reach, y: rightOut[last].y + tangent.y * reach))
        cap.addLine(to: rightOut[last])
        cap.closeSubpath()
        ctx.setFillColor(shade(1).cgColor)
        ctx.addPath(cap)
        ctx.fillPath()
        ctx.restoreGState()
    }
}
