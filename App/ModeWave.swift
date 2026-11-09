import SwiftUI

/// The wave that carries the Themes screen from light to dark and back: a ring of Liquid Glass with wavy edges
/// spreads out from the middle of the screen, and every preview shows its new look inside the ring and its old look
/// outside it.
///
/// The screen owns the wave (ThemesView) and hands it down in the environment; the previews cut themselves at its
/// front (`revealedByWave`), each from where it is on the screen, so the cut is one curve across all of them,
/// hidden under the ring. `progress` follows `started` on the animation's own curve (`ModeWave.ease`), so SwiftUI's
/// views and the keyboard's Core Animation layers, which both read that clock, are always at the same place.
struct ModeWave: Equatable {
    let id: Int
    /// 0: the ring is a point in the middle; 1: it has left the screen.
    var progress: CGFloat
    /// The mode the previews are leaving.
    let oldScheme: ColorScheme
    /// The screen's frame, in the window's coordinates.
    let minX: CGFloat
    let minY: CGFloat
    let width: CGFloat
    let height: CGFloat
    /// When the wave set off (CACurrentMediaTime).
    let started: CFTimeInterval

    static let duration: TimeInterval = 1.1
    /// The ring's thickness.
    static let band: CGFloat = 96
    /// How many crests the edge has, and how high they are as a share of the radius.
    static let crests = 9.0
    static let swell: CGFloat = 0.05
    private static let steps = 144

    /// The wave now crossing the screen, for the code that learns of the new mode outside SwiftUI's updates (the
    /// keyboard's rebuild, a card's picture arriving from the queue).
    static var active: ModeWave?
    static var count = 0

    var center: CGPoint { return CGPoint(x: minX + width / 2, y: minY + height / 2) }

    /// The radius the cut has at the end, when the ring's inner edge has passed the screen's farthest corner.
    var endRadius: CGFloat {
        return (hypot(width, height) / 2 + ModeWave.band / 2) / (1 - ModeWave.swell)
    }

    /// The radius of the cut at `angle`.
    func radius(_ progress: CGFloat, angle: Double) -> CGFloat {
        return progress * endRadius * (1 + ModeWave.swell * CGFloat(sin(ModeWave.crests * angle)))
    }

    /// The cut's outline at `progress`, a point at every step around, relative to `origin` (window coordinates).
    func outline(_ progress: CGFloat, relativeTo origin: CGPoint) -> [CGPoint] {
        return (0..<ModeWave.steps).map { index in
            let angle = Double(index) / Double(ModeWave.steps) * 2 * .pi
            let r = radius(progress, angle: angle)
            return CGPoint(x: center.x + r * CGFloat(cos(angle)) - origin.x,
                           y: center.y + r * CGFloat(sin(angle)) - origin.y)
        }
    }

    /// The ring: the inner and the outer edge at every step around, relative to `origin`.
    func ring(_ progress: CGFloat, relativeTo origin: CGPoint) -> (inner: [CGPoint], outer: [CGPoint]) {
        var inner: [CGPoint] = [], outer: [CGPoint] = []
        for index in 0..<ModeWave.steps {
            let angle = Double(index) / Double(ModeWave.steps) * 2 * .pi
            let r = radius(progress, angle: angle)
            let half = ModeWave.band / 2
            let near = max(0, r - half), far = r + min(half, r)
            let direction = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
            inner.append(CGPoint(x: center.x + near * direction.x - origin.x, y: center.y + near * direction.y - origin.y))
            outer.append(CGPoint(x: center.x + far * direction.x - origin.x, y: center.y + far * direction.y - origin.y))
        }
        return (inner, outer)
    }

    /// The animation's curve (ease in, ease out: the same as Core Animation's `easeInEaseOut`, which the keyboard's
    /// layers use), for a share `t` of the duration.
    static func ease(_ t: CGFloat) -> CGFloat {
        let t = min(1, max(0, t))
        // Cubic Bézier (0.42, 0, 0.58, 1): solve x(s) = t for s, then y(s).
        func coordinate(_ s: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
            let inverse = 1 - s
            return 3 * inverse * inverse * s * a + 3 * inverse * s * s * b + s * s * s
        }
        var low: CGFloat = 0, high: CGFloat = 1
        for _ in 0..<24 {
            let mid = (low + high) / 2
            if coordinate(mid, 0.42, 0.58) < t { low = mid } else { high = mid }
        }
        return coordinate((low + high) / 2, 0, 1)
    }
}

private struct ModeWaveKey: EnvironmentKey {
    static let defaultValue: ModeWave? = nil
}

extension EnvironmentValues {
    /// The light / dark wave crossing the screen, if one is.
    var modeWave: ModeWave? {
        get { return self[ModeWaveKey.self] }
        set { self[ModeWaveKey.self] = newValue }
    }
}

/// Calls `onFrame` with the clock (CACurrentMediaTime) on every screen refresh, until stopped.
final class WaveDriver: NSObject {
    private var link: CADisplayLink?
    private var onFrame: ((CFTimeInterval) -> Void)?

    func start(_ onFrame: @escaping (CFTimeInterval) -> Void) {
        stop()
        self.onFrame = onFrame
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        onFrame = nil
    }

    @objc private func step() {
        onFrame?(CACurrentMediaTime())
    }
}

/// The part of a view the wave has passed: everything inside its wavy circle. `origin` is the view's top left in
/// the window.
private struct WavePassed: Shape {
    let wave: ModeWave
    let origin: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = wave.outline(wave.progress, relativeTo: origin)
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}

extension View {
    /// While a wave crosses the screen, shows the view only where it has passed (what is drawn under the view,
    /// its old look, shows outside the front). Without a wave the view is shown whole.
    func revealedByWave(_ wave: ModeWave?) -> some View {
        return mask {
            if let wave = wave {
                GeometryReader { geometry in
                    WavePassed(wave: wave, origin: geometry.frame(in: .global).origin)
                }
            } else {
                Rectangle()
            }
        }
    }
}

/// The ring itself, over the whole screen: Liquid Glass with wavy edges, spreading out with the wave's front.
struct GlassWaveBand: View {
    let wave: ModeWave

    var body: some View {
        GeometryReader { geometry in
            WaveGlass(wave: wave, origin: geometry.frame(in: .global).origin)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Liquid Glass in the ring's shape (a frosted material before iOS 26), with a rim of light on its edges.
private struct WaveGlass: View {
    let wave: ModeWave
    let origin: CGPoint

    private var shape: WaveRingShape { return WaveRingShape(wave: wave, origin: origin) }

    var body: some View {
        glass
            .overlay(shape.stroke(LinearGradient(colors: [Color.white.opacity(0.75), Color.white.opacity(0.15),
                                                          Color.white.opacity(0.55)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 0)
    }

    @ViewBuilder private var glass: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.clear, in: shape)
        } else {
            frosted
        }
        #else
        frosted
        #endif
    }

    private var frosted: some View {
        return shape.fill(.ultraThinMaterial)
            .overlay(shape.fill(LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                                               startPoint: .top, endPoint: .bottom)))
    }
}

/// A ring whose two edges are the wave's wavy circle, half a band inside it and half a band outside.
private struct WaveRingShape: Shape {
    let wave: ModeWave
    let origin: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let ring = wave.ring(wave.progress, relativeTo: origin)
        guard let first = ring.outer.first, let start = ring.inner.last else { return path }
        path.move(to: first)
        for point in ring.outer.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        // The inner edge runs the other way round, so the middle is left open.
        path.move(to: start)
        for point in ring.inner.reversed().dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}
