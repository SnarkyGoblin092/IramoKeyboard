import SwiftUI

/// The wave that carries the Themes screen from light to dark and back: a thin, irregular ring of Liquid Glass
/// spreads out from the middle of the screen, and every preview shows its new look inside the ring and its old look
/// outside it. Switching again while a wave is out sends another one after it; the waves layer on each other.
///
/// The screen keeps the running waves (ThemesView) and hands them down in the environment. Nothing is updated for
/// each frame of a wave: whoever draws it (the previews' masks, the ring, the keyboard's layers) reads the clock
/// itself, `progress(at:)`, so they are always at the same place.
struct ModeWave: Equatable, Identifiable {
    let id: Int
    /// The mode the previews are leaving.
    let oldScheme: ColorScheme
    /// The screen's frame, in the window's coordinates.
    let minX: CGFloat
    let minY: CGFloat
    let width: CGFloat
    let height: CGFloat
    /// When the wave set off, on the two clocks that are read.
    let started: CFTimeInterval
    let startedDate: Date

    static let duration: TimeInterval = 1.1
    /// The ring's thickness.
    static let band: CGFloat = 19
    private static let steps = 90

    /// The waves now crossing the screen, for the code that learns of the new mode outside SwiftUI's updates (the
    /// keyboard's rebuild, a card's picture arriving from the queue).
    static var running: [ModeWave] = []
    static var count = 0

    /// The crests of the edge: how many around, how high (as a share of the radius), where they start and how far
    /// they travel round as the wave spreads. No two are alike, so the edge never repeats itself.
    private static let crests: [(count: Double, height: CGFloat, phase: Double, drift: Double)] = [
        (2, 0.050, 0.4, 1.7), (3, 0.045, 2.1, -2.3), (5, 0.030, 4.0, 3.1), (8, 0.018, 1.1, -4.2), (13, 0.010, 5.3, 5.0)
    ]
    private static let reach: CGFloat = 0.153

    var center: CGPoint { return CGPoint(x: minX + width / 2, y: minY + height / 2) }

    /// Each wave has its own edge.
    private var shift: Double { return Double(id) * 1.618 }

    /// The share of the wave's way it has gone at `date`, on the animation's curve.
    func progress(at date: Date) -> CGFloat {
        return ModeWave.ease(CGFloat(date.timeIntervalSince(startedDate) / ModeWave.duration))
    }

    func progress(atMediaTime time: CFTimeInterval) -> CGFloat {
        return ModeWave.ease(CGFloat((time - started) / ModeWave.duration))
    }

    /// The radius the cut has at the end, when the ring's inner edge has passed the screen's farthest corner.
    private var endRadius: CGFloat {
        return (hypot(width, height) / 2 + ModeWave.band) / (1 - ModeWave.reach)
    }

    /// The radius of the cut at `angle`.
    private func radius(_ progress: CGFloat, angle: Double) -> CGFloat {
        var swell: CGFloat = 1
        for crest in ModeWave.crests {
            swell += crest.height * CGFloat(sin(crest.count * angle + crest.phase + shift + crest.drift * Double(progress)))
        }
        return progress * endRadius * swell
    }

    /// The ring's half thickness at `angle`: thicker here, thinner there.
    private func half(angle: Double) -> CGFloat {
        return ModeWave.band / 2 * CGFloat(1 + 0.45 * sin(4 * angle + shift) + 0.2 * sin(7 * angle + 2 * shift))
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
            let half = self.half(angle: angle)
            let near = max(0, r - half), far = r + min(half, r)
            let direction = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
            inner.append(CGPoint(x: center.x + near * direction.x - origin.x, y: center.y + near * direction.y - origin.y))
            outer.append(CGPoint(x: center.x + far * direction.x - origin.x, y: center.y + far * direction.y - origin.y))
        }
        return (inner, outer)
    }

    /// The animation's curve (ease in, ease out: the same as Core Animation's `easeInEaseOut`), for a share `t` of
    /// the duration.
    static func ease(_ t: CGFloat) -> CGFloat {
        let t = min(1, max(0, t))
        // Cubic Bézier (0.42, 0, 0.58, 1): solve x(s) = t for s, then y(s).
        func coordinate(_ s: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
            let inverse = 1 - s
            return 3 * inverse * inverse * s * a + 3 * inverse * s * s * b + s * s * s
        }
        var low: CGFloat = 0, high: CGFloat = 1
        for _ in 0..<20 {
            let mid = (low + high) / 2
            if coordinate(mid, 0.42, 0.58) < t { low = mid } else { high = mid }
        }
        return coordinate((low + high) / 2, 0, 1)
    }
}

private struct ModeWavesKey: EnvironmentKey {
    static let defaultValue: [ModeWave] = []
}

extension EnvironmentValues {
    /// The light / dark waves crossing the screen, oldest first.
    var modeWaves: [ModeWave] {
        get { return self[ModeWavesKey.self] }
        set { self[ModeWavesKey.self] = newValue }
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

/// The part of a view the wave has passed: everything inside its irregular circle. `origin` is the view's top left
/// in the window.
private struct WavePassed: Shape {
    let wave: ModeWave
    let progress: CGFloat
    let origin: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = wave.outline(progress, relativeTo: origin)
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
                TimelineView(.animation) { context in
                    GeometryReader { geometry in
                        WavePassed(wave: wave, progress: wave.progress(at: context.date),
                                   origin: geometry.frame(in: .global).origin)
                    }
                }
            } else {
                Rectangle()
            }
        }
    }
}

/// The rings themselves, over the whole screen: Liquid Glass spreading out with the waves' fronts.
struct GlassWaveBand: View {
    let waves: [ModeWave]

    var body: some View {
        GeometryReader { geometry in
            let origin = geometry.frame(in: .global).origin
            TimelineView(.animation) { context in
                ZStack {
                    ForEach(waves) { wave in
                        WaveGlass(wave: wave, progress: wave.progress(at: context.date), origin: origin)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Liquid Glass in the ring's shape (a frosted material before iOS 26), with a rim of light on its edges.
private struct WaveGlass: View {
    let wave: ModeWave
    let progress: CGFloat
    let origin: CGPoint

    private var shape: WaveRingShape { return WaveRingShape(wave: wave, progress: progress, origin: origin) }

    var body: some View {
        glass
            .overlay(shape.stroke(Color.white.opacity(0.5), lineWidth: 0.75))
            .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 0)
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
            .overlay(shape.fill(Color.white.opacity(0.12)))
    }
}

/// A ring whose two edges follow the wave's front, half a band inside it and half a band outside.
private struct WaveRingShape: Shape {
    let wave: ModeWave
    let progress: CGFloat
    let origin: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard progress > 0, progress < 1 else { return path }
        let ring = wave.ring(progress, relativeTo: origin)
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
