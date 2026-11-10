import SwiftUI

/// The wave that carries the Themes screen from light to dark and back: a thin, irregular ring of Liquid Glass
/// spreads out from the middle of the screen, and every preview shows its new look inside the ring and its old look
/// outside it. Switching again while a wave is out sends another one after it; the waves layer on each other.
///
/// The screen keeps the running waves (ThemesView) and hands them down in the environment. Nothing is updated for
/// each frame of a wave: whoever draws it (the previews' masks, the ring, the keyboard's layers) reads the clock
/// itself, `progress(at:)`, so they are always at the same place.
struct ModeWave: Equatable, Identifiable {
    enum Kind { case mode, theme }

    let id: Int
    /// A light / dark wave crossing the whole screen, or a wave of a new theme inside the main preview.
    let kind: Kind
    /// The mode and the theme the main preview is leaving, and the ones it is going to.
    let oldScheme: ColorScheme
    let newScheme: ColorScheme
    let oldTheme: String
    let newTheme: String
    /// Where the circle starts, in the window's coordinates: where the finger touched (a theme wave: the bottom of
    /// the preview).
    let source: CGPoint
    /// The screen's frame, in the window's coordinates.
    let minX: CGFloat
    let minY: CGFloat
    let width: CGFloat
    let height: CGFloat
    /// When the wave set off, on the two clocks that are read.
    let started: CFTimeInterval
    let startedDate: Date

    static let duration: TimeInterval = 1.2
    /// The ring's thickness.
    static let band: CGFloat = 19
    private static let steps = 64

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

    /// The main preview's box in the window, for the theme waves (set by LiveKeyboard).
    static var previewBox = CGRect.zero

    var center: CGPoint { return source }

    /// Each wave has its own edge.
    var shift: Double { return Double(id) * 1.618 }

    /// The share of the wave's way it has gone at `date`, on the animation's curve.
    func progress(at date: Date) -> CGFloat {
        return ModeWave.ease(CGFloat(date.timeIntervalSince(startedDate) / ModeWave.duration))
    }

    func progress(atMediaTime time: CFTimeInterval) -> CGFloat {
        return ModeWave.ease(CGFloat((time - started) / ModeWave.duration))
    }

    /// The radius the cut has at the end, when the ring's inner edge has passed the screen's farthest corner.
    var endRadius: CGFloat {
        // The farthest corner of the frame from where the circle starts.
        let far = max(hypot(source.x - minX, source.y - minY), hypot(source.x - minX - width, source.y - minY),
                      hypot(source.x - minX, source.y - minY - height),
                      hypot(source.x - minX - width, source.y - minY - height))
        return (far + ModeWave.band) / (1 - ModeWave.reach) * 1.15
    }

    /// The radius of the cut at `angle`.
    private func radius(_ progress: CGFloat, angle: Double) -> CGFloat {
        var swell: CGFloat = 1
        for crest in ModeWave.crests {
            swell += crest.height * CGFloat(sin(crest.count * angle + crest.phase + shift + crest.drift * Double(progress)))
        }
        return progress * endRadius * swell
    }

    /// The ring's half thickness: the same all round, so the cut never shows outside the ring.
    private func half(angle: Double) -> CGFloat {
        return ModeWave.band / 2
    }

    enum Relation { case passed, ahead, crossing }

    /// Whether the wave at `progress` has passed all of `frame`, not reached any of it, or is crossing it. (Judged
    /// by points of the frame and a margin, so a view is only called passed or ahead when it surely is.)
    func relation(of frame: CGRect, progress: CGFloat) -> Relation {
        guard frame.width > 0, frame.height > 0 else { return .crossing }
        let margin: CGFloat = 12
        var inside = 0, outside = 0
        let xs = [frame.minX, frame.midX, frame.maxX], ys = [frame.minY, frame.midY, frame.maxY]
        for x in xs {
            for y in ys {
                let dx = x - center.x, dy = y - center.y
                let distance = hypot(dx, dy)
                let r = radius(progress, angle: atan2(Double(dy), Double(dx)).truncatingRemainder(dividingBy: 2 * .pi))
                if distance < r - margin - ModeWave.band { inside += 1 } else if distance > r + margin + ModeWave.band { outside += 1 }
            }
        }
        if inside == 9 { return .passed }
        if outside == 9 { return .ahead }
        return .crossing
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
    func ring(_ progress: CGFloat, relativeTo origin: CGPoint, grow: CGFloat = 0) -> (inner: [CGPoint], outer: [CGPoint]) {
        var inner: [CGPoint] = [], outer: [CGPoint] = []
        for index in 0..<ModeWave.steps {
            let angle = Double(index) / Double(ModeWave.steps) * 2 * .pi
            let r = radius(progress, angle: angle)
            let half = self.half(angle: angle)
            let near = max(0, r - half - grow), far = r + min(half, r) + grow
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
        return modifier(WaveReveal(wave: wave))
    }
}

/// Masks the view to the wave's circle, but only while the circle's edge crosses it: a view the wave has not
/// reached is not drawn, and one it has passed by is drawn whole, without the mask (which costs a pass each).
private struct WaveReveal: ViewModifier {
    let wave: ModeWave?
    @State private var frame = CGRect.zero

    func body(content: Content) -> some View {
        Group {
            if let wave = wave {
                TimelineView(.animation) { context in
                    let progress = wave.progress(at: context.date)
                    switch wave.relation(of: frame, progress: progress) {
                    case .passed:
                        content
                    case .ahead:
                        // (Hidden, not removed: it keeps its size, which the frame measured here comes from.)
                        content.hidden()
                    case .crossing:
                        content.mask(WavePassed(wave: wave, progress: progress, origin: frame.origin))
                    }
                }
            } else {
                content
            }
        }
        .background(GeometryReader { geometry in
            Color.clear
                .onAppear { frame = geometry.frame(in: .global) }
                .onChange(of: geometry.frame(in: .global)) { frame = $0 }
        })
    }
}

/// The rings themselves, over the whole screen: Liquid Glass spreading out with the waves' fronts.
struct GlassWaveBand: View {
    let waves: [ModeWave]
    /// Over the whole screen, safe areas and all (else only its own box).
    var fullScreen = true

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
        .ignoresSafeArea(edges: fullScreen ? .all : [])
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Liquid Glass over the circle the wave has covered (a frosted material before iOS 26).
private struct WaveGlass: View {
    let wave: ModeWave
    let progress: CGFloat
    let origin: CGPoint

    private var ring: WaveRingShape { return WaveRingShape(wave: wave, progress: progress, origin: origin) }
    private var rim: WaveDiscShape { return WaveDiscShape(wave: wave, progress: progress, origin: origin) }

    /// A thin ring of Liquid Glass at the front (what it covers, the inside of the circle, is left clear: the new
    /// look shows there as it is), with a bright blue line and a blue glow on its outer edge. The shader
    /// (WaveLens.metal) bends the colours around it.
    var body: some View {
        glass
            .background(rim.stroke(Color(red: 0.30, green: 0.50, blue: 1.0), lineWidth: 8).blur(radius: 5).opacity(0.75))
            .overlay(rim.stroke(Color(red: 0.62, green: 0.75, blue: 1.0).opacity(0.95), lineWidth: 2))
    }

    @ViewBuilder private var glass: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.clear, in: ring)
        } else {
            frosted
        }
        #else
        frosted
        #endif
    }

    private var frosted: some View {
        return ring.fill(.ultraThinMaterial)
            .overlay(ring.fill(Color.white.opacity(0.08)))
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
        // What lies beyond the screen is not drawn: points out there are pulled in to just outside it.
        let bounds = rect.insetBy(dx: -40, dy: -40)
        func held(_ point: CGPoint) -> CGPoint {
            return CGPoint(x: min(bounds.maxX, max(bounds.minX, point.x)), y: min(bounds.maxY, max(bounds.minY, point.y)))
        }
        guard let first = ring.outer.first, let start = ring.inner.last else { return path }
        path.move(to: held(first))
        for point in ring.outer.dropFirst() { path.addLine(to: held(point)) }
        path.closeSubpath()
        // The inner edge runs the other way round, so the middle is left open.
        path.move(to: held(start))
        for point in ring.inner.reversed().dropFirst() { path.addLine(to: held(point)) }
        path.closeSubpath()
        return path
    }
}

/// The wave's outer edge, half a band beyond its front (for the rim's line and glow).
private struct WaveDiscShape: Shape {
    let wave: ModeWave
    let progress: CGFloat
    let origin: CGPoint
    var grow: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard progress > 0, progress < 1 else { return path }
        let edge = wave.ring(progress, relativeTo: origin, grow: grow).outer
        // What lies beyond the screen is not drawn (the glass costs more the more it covers): points out there are
        // pulled in to just outside it.
        let bounds = rect.insetBy(dx: -40, dy: -40)
        func held(_ point: CGPoint) -> CGPoint {
            return CGPoint(x: min(bounds.maxX, max(bounds.minX, point.x)), y: min(bounds.maxY, max(bounds.minY, point.y)))
        }
        guard let first = edge.first else { return path }
        path.move(to: held(first))
        for point in edge.dropFirst() { path.addLine(to: held(point)) }
        path.closeSubpath()
        return path
    }
}

extension View {
    /// Bends and splits the colours of what is drawn around the light / dark waves' fronts (WaveLens.metal), as
    /// light is at the edge of a thick lens. (Needs iOS 17; earlier the glass ring alone is the effect. Views the
    /// system draws itself, as the keyboard's keys, cannot be reached by a shader.)
    func waveLensed(_ waves: [ModeWave]) -> some View {
        return modifier(WaveLens(waves: waves))
    }
}

private struct WaveLens: ViewModifier {
    let waves: [ModeWave]
    /// Where the view is in the window (not state: scrolling would redraw it for nothing; the clock redraws it
    /// while a wave is out).
    @State private var place = Place()

    private final class Place {
        var origin = CGPoint.zero
    }

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 17.0, *), !waves.isEmpty {
                TimelineView(.animation) { context in
                    lensed(content, at: context.date, from: 0)
                }
            } else {
                content
            }
        }
        .background(GeometryReader { geometry in
            Color.clear
                .onAppear { place.origin = geometry.frame(in: .global).origin }
                .onChange(of: geometry.frame(in: .global)) { place.origin = $0.origin }
        })
    }

    /// The content with the waves from `index` on applied, one over the other.
    @available(iOS 17.0, *)
    private func lensed(_ content: Content, at date: Date, from index: Int) -> AnyView {
        guard index < waves.count else { return AnyView(content) }
        let wave = waves[index]
        let progress = wave.progress(at: date)
        let inner = lensed(content, at: date, from: index + 1)
        guard progress > 0, progress < 1 else { return inner }
        let shader = ShaderLibrary.waveLens(
            .float2(CGPoint(x: wave.center.x - place.origin.x, y: wave.center.y - place.origin.y)),
            .float(Float(progress)), .float(Float(wave.endRadius)), .float(Float(wave.shift)),
            .float(Float(ModeWave.band * 2.0)), .float(10))
        return AnyView(inner.layerEffect(shader, maxSampleOffset: CGSize(width: 24, height: 24)))
    }
}
