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
    /// The mode and the theme the main preview is leaving, and the ones it is going to.
    let oldScheme: ColorScheme
    let newScheme: ColorScheme
    let oldTheme: String
    let newTheme: String
    /// Where the circle starts, in the window's coordinates: where the finger touched.
    let source: CGPoint
    /// The screen's frame, in the window's coordinates.
    let minX: CGFloat
    let minY: CGFloat
    let width: CGFloat
    let height: CGFloat
    /// When the wave set off, on the two clocks that are read.
    let started: CFTimeInterval
    let startedDate: Date

    static let duration: TimeInterval = 1.4
    /// The ring's thickness.
    static let band: CGFloat = 19
    /// The longest the wave's drawings wait between frames (60 a second).
    static let frame: TimeInterval = 1.0 / 60
    private static let steps = 80

    /// The waves now crossing the screen, for the code that learns of the new mode outside SwiftUI's updates (the
    /// keyboard's rebuild, a card's picture arriving from the queue).
    static var running: [ModeWave] = []
    static var count = 0

    /// The crests of the edge: how many around, how high (as a share of the radius), where they start and how far
    /// they travel round as the wave spreads. No two are alike, so the edge never repeats itself.
    private static let crests: [(count: Double, height: CGFloat, phase: Double, drift: Double)] = [
        (2, 0.110, 0.4, 1.7), (3, 0.090, 2.1, -2.3), (5, 0.060, 4.0, 3.1), (7, 0.035, 1.1, -4.2), (11, 0.020, 5.3, 5.0)
    ]
    private static let reach: CGFloat = 0.315

    /// The share of the way at which the whole ring has left the frame (the radius runs 15% past what that takes).
    static let doneShare: CGFloat = 1 / 1.15
    /// How far from the front the lens (WaveLens.metal) still bends what is under it: 2.2 reaches, and a little.
    static let lensReach: CGFloat = band * 2 * 2.2 + 2
    /// How far past a point the front must be before the lens's bend there is too faint to see go.
    private static let lensFade: CGFloat = 64

    /// How long the wave takes to go `share` of its way (the curve, turned round).
    static func time(reaching share: CGFloat) -> TimeInterval {
        var low: CGFloat = 0, high: CGFloat = 1
        for _ in 0..<30 {
            let mid = (low + high) / 2
            if ease(mid) < share { low = mid } else { high = mid }
        }
        return TimeInterval(high) * duration
    }

    /// How long this wave lives: until its ring has left its frame, wherever it started and whatever its edge is
    /// like, not until the slowest edge there could be would have (which is `doneShare`, the latest it can be).
    /// Worked out once, as the wave sets off.
    var lifetime: TimeInterval {
        let margin = ModeWave.lensFade
        // The frame's edge, as seen from where the wave starts: the wave is past the frame when it is past these.
        var edge: [(distance: CGFloat, angle: Double)] = []
        let perSide = 16
        for index in 0..<perSide {
            let share = CGFloat(index) / CGFloat(perSide)
            let points = [CGPoint(x: minX + share * width, y: minY), CGPoint(x: minX + width, y: minY + share * height),
                          CGPoint(x: minX + width - share * width, y: minY + height),
                          CGPoint(x: minX, y: minY + height - share * height)]
            for point in points {
                let dx = point.x - center.x, dy = point.y - center.y
                edge.append((hypot(dx, dy), atan2(Double(dy), Double(dx))))
            }
        }
        // Back from the latest it can be, to the last share of the way at which some of the frame is not passed.
        var done = ModeWave.doneShare
        var share = done - 0.01
        while share > 0 {
            if edge.contains(where: { $0.distance > radius(share, angle: $0.angle) - margin }) { break }
            done = share
            share -= 0.01
        }
        return ModeWave.time(reaching: done)
    }

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
    /// by points of the frame and a margin, so a view is only called passed or ahead when it surely is: `reach`
    /// is how far from the front still counts as crossing.)
    func relation(of frame: CGRect, progress: CGFloat, within reach: CGFloat = 12 + ModeWave.band) -> Relation {
        guard frame.width > 0, frame.height > 0 else { return .crossing }
        var inside = 0, outside = 0
        let xs = [frame.minX, frame.midX, frame.maxX], ys = [frame.minY, frame.midY, frame.maxY]
        for x in xs {
            for y in ys {
                let dx = x - center.x, dy = y - center.y
                let distance = hypot(dx, dy)
                let r = radius(progress, angle: atan2(Double(dy), Double(dx)).truncatingRemainder(dividingBy: 2 * .pi))
                if distance < r - reach { inside += 1 } else if distance > r + reach { outside += 1 }
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

/// Everything outside the wave's circle (the inside is cut out).
private struct WaveAhead: Shape {
    let wave: ModeWave
    let progress: CGFloat
    let origin: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(CGRect(x: -4000, y: -4000, width: 8000, height: 8000))
        let points = wave.outline(progress, relativeTo: origin)
        if let first = points.first {
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
            path.closeSubpath()
        }
        return path
    }
}

extension View {
    /// The other half of revealedByWave: the view is shown only outside the wave's circle (the old look, which the
    /// new one replaces as the wave passes, so the two are never seen together).
    func hiddenByWave(_ wave: ModeWave?) -> some View {
        return modifier(WaveHide(wave: wave))
    }
}

private struct WaveHide: ViewModifier {
    let wave: ModeWave?
    @State private var frame = CGRect.zero

    func body(content: Content) -> some View {
        Group {
            if let wave = wave {
                TimelineView(.animation(minimumInterval: ModeWave.frame)) { context in
                    let progress = wave.progress(at: context.date)
                    switch wave.relation(of: frame, progress: progress) {
                    case .passed:
                        content.hidden()
                    case .ahead:
                        content
                    case .crossing:
                        content.mask(WaveAhead(wave: wave, progress: progress, origin: frame.origin)
                            .fill(style: FillStyle(eoFill: true)))
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

/// Masks the view to the wave's circle, but only while the circle's edge crosses it: a view the wave has not
/// reached is not drawn, and one it has passed by is drawn whole, without the mask (which costs a pass each).
private struct WaveReveal: ViewModifier {
    let wave: ModeWave?
    @State private var frame = CGRect.zero

    func body(content: Content) -> some View {
        Group {
            if let wave = wave {
                TimelineView(.animation(minimumInterval: ModeWave.frame)) { context in
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
    var body: some View {
        GeometryReader { geometry in
            let origin = geometry.frame(in: .global).origin
            TimelineView(.animation(minimumInterval: ModeWave.frame)) { context in
                ZStack {
                    ForEach(waves) { wave in
                        WaveGlass(wave: wave, progress: wave.progress(at: context.date), origin: origin, size: geometry.size)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Liquid Glass over the circle the wave has covered (a frosted material before iOS 26).
private struct WaveGlass: View {
    let wave: ModeWave
    let progress: CGFloat
    let origin: CGPoint

    let size: CGSize

    private var ring: WaveRingShape { return WaveRingShape(wave: wave, progress: progress, origin: origin) }
    private var rim: WaveDiscShape { return WaveDiscShape(wave: wave, progress: progress, origin: origin) }

    /// A thin ring of Liquid Glass at the front (what it covers, the inside of the circle, is left clear: the new
    /// look shows there as it is), with a bright blue line and a blue glow on its outer edge, and a shine of
    /// colours running round the line. The shader (WaveLens.metal) bends the colours around it.
    ///
    /// The glow is a few strokes of falling strength, not a blur: a blur of the whole screen's size every frame
    /// is what made it slow. The outline is worked out once a frame and all its strokes are drawn in three
    /// canvases (under the glass, the line, the shine), not a layer of the screen's size for each stroke.
    var body: some View {
        let line = rim.path(in: CGRect(origin: .zero, size: size))
        let blue = WaveGlass.blue
        let shine = GraphicsContext.Shading.conicGradient(
            Gradient(colors: WaveGlass.colors),
            center: CGPoint(x: wave.center.x - origin.x, y: wave.center.y - origin.y),
            angle: .degrees(Double(progress) * 300))
        return glass
            .background(Canvas { context, _ in
                for stroke in WaveGlass.glow {
                    context.stroke(line, with: .color(blue.opacity(stroke.opacity)), lineWidth: stroke.width)
                }
            })
            .overlay(Canvas { context, _ in
                context.stroke(line, with: .color(Color(red: 0.62, green: 0.75, blue: 1.0).opacity(0.95)), lineWidth: 2)
            })
            .overlay(Canvas { context, _ in
                for stroke in WaveGlass.shine {
                    context.opacity = stroke.opacity
                    context.stroke(line, with: shine, lineWidth: stroke.width)
                }
            }.blendMode(.plusLighter))
    }

    private static let blue = Color(red: 0.30, green: 0.50, blue: 1.0)

    /// The blue glow under the glass, and the shine's own glow of colours over it: widest and faintest first.
    private static let glow: [(width: CGFloat, opacity: Double)] = [(26, 0.07), (18, 0.12), (11, 0.20), (5, 0.40)]
    private static let shine: [(width: CGFloat, opacity: Double)] = [(22, 0.16), (11, 0.36), (3.5, 0.95)]

    /// The colours of the shine, turning round the front as it spreads.
    private static let colors: [Color] = [
        Color(red: 1.0, green: 0.40, blue: 0.75), Color(red: 1.0, green: 0.40, blue: 0.40),
        Color(red: 1.0, green: 0.62, blue: 0.30), Color(red: 1.0, green: 0.88, blue: 0.35),
        Color(red: 0.65, green: 1.0, blue: 0.40), Color(red: 0.40, green: 1.0, blue: 0.70),
        Color(red: 0.35, green: 0.95, blue: 1.0), Color(red: 0.35, green: 0.65, blue: 1.0),
        Color(red: 0.50, green: 0.45, blue: 1.0), Color(red: 0.75, green: 0.45, blue: 1.0),
        Color(red: 1.0, green: 0.45, blue: 0.95), Color(red: 1.0, green: 0.40, blue: 0.75)
    ]

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
        guard progress > 0, progress < ModeWave.doneShare else { return path }
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
        guard progress > 0, progress < ModeWave.doneShare else { return path }
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
    ///
    /// For small views (a card), not a whole screen of them: a view under the shader is drawn again into a
    /// picture of its own every frame, so only the ones the front is near are (the others stay as they are).
    func waveLensed(_ waves: [ModeWave]) -> some View {
        return modifier(WaveLens(waves: waves))
    }
}

/// The view is always the same one, wave or no wave (the shader is only switched on and off, and the clock
/// stopped): were it wrapped in something else while a wave is out, it would be built anew as each wave sets off
/// and again as it ends.
private struct WaveLens: ViewModifier {
    let waves: [ModeWave]
    /// Where the view is in the window (not state: nothing is to be redrawn for it; the clock redraws the view
    /// while a wave is out). Only measured while a wave is out.
    @State private var place = Place()

    private final class Place {
        var frame = CGRect.zero
    }

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 17.0, *) {
                TimelineView(.animation(minimumInterval: ModeWave.frame, paused: waves.isEmpty)) { context in
                    let lens = self.lens(at: context.date)
                    content.layerEffect(lens ?? WaveLens.shader(center: .zero, progress: 0, endRadius: 0, shift: 0),
                                        maxSampleOffset: CGSize(width: 24, height: 24), isEnabled: lens != nil)
                }
            } else {
                content
            }
        }
        .background {
            if !waves.isEmpty {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { place.frame = geometry.frame(in: .global) }
                        .onChange(of: geometry.frame(in: .global)) { place.frame = $0 }
                }
            }
        }
    }

    /// The lens of the wave whose front is near the view at `date` (nil: none is, and the view is left alone).
    /// Only one wave is out at a time (ThemesView).
    @available(iOS 17.0, *)
    private func lens(at date: Date) -> Shader? {
        let frame = place.frame
        guard frame.width > 0, frame.height > 0 else { return nil }
        for wave in waves {
            let progress = wave.progress(at: date)
            guard progress > 0, progress < ModeWave.doneShare,
                  wave.relation(of: frame, progress: progress, within: ModeWave.lensReach) == .crossing else { continue }
            return WaveLens.shader(center: CGPoint(x: wave.center.x - frame.minX, y: wave.center.y - frame.minY),
                                   progress: progress, endRadius: wave.endRadius, shift: wave.shift)
        }
        return nil
    }

    @available(iOS 17.0, *)
    private static func shader(center: CGPoint, progress: CGFloat, endRadius: CGFloat, shift: Double) -> Shader {
        return ShaderLibrary.waveLens(
            .float2(center), .float(Float(progress)), .float(Float(endRadius)), .float(Float(shift)),
            .float(Float(ModeWave.band * 2.0)), .float(10))
    }
}

/// Carries the whole app across a light / dark change: a picture of the window as it was lies over it, cut away
/// outside the wave's front as the wave spreads, so the app's new mode shows only where the wave has passed.
/// Started before the setting changes.
enum WindowWaveCover {
    private static let driver = WaveDriver()
    private static var covers: [(wave: ModeWave, view: UIView, mask: CAShapeLayer, ends: CFTimeInterval)] = []

    /// `leaving`: a part of the window that is not covered (the control that was just used).
    static func start(for wave: ModeWave, leaving hole: CGRect = .zero) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let window = scenes.flatMap({ $0.windows }).first(where: { $0.isKeyWindow }),
              let picture = window.snapshotView(afterScreenUpdates: false) else { return }
        picture.frame = window.bounds
        // The picture lacks the part that is left out; the container is cut to the outside of the wave.
        if !hole.isEmpty {
            let leave = CAShapeLayer()
            leave.fillRule = .evenOdd
            leave.fillColor = UIColor.black.cgColor
            leave.frame = window.bounds
            let path = CGMutablePath()
            path.addRect(window.bounds)
            path.addRoundedRect(in: hole, cornerWidth: 9, cornerHeight: 9)
            leave.path = path
            picture.layer.mask = leave
        }
        let container = UIView(frame: window.bounds)
        container.isUserInteractionEnabled = false
        container.addSubview(picture)
        let mask = CAShapeLayer()
        mask.fillRule = .evenOdd
        mask.fillColor = UIColor.black.cgColor
        mask.frame = window.bounds
        container.layer.mask = mask
        window.addSubview(container)
        covers.append((wave, container, mask, wave.started + wave.lifetime))
        update(at: CACurrentMediaTime())
        driver.start { update(at: $0) }
    }

    private static func update(at time: CFTimeInterval) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for cover in covers {
            if time >= cover.ends {
                cover.view.removeFromSuperview()
                continue
            }
            let path = CGMutablePath()
            path.addRect(CGRect(x: -4000, y: -4000, width: 8000, height: 8000))
            // Cut out to the ring's outer edge, so the glass ring itself is not hidden.
            let points = cover.wave.ring(cover.wave.progress(atMediaTime: time), relativeTo: .zero).outer
            if let first = points.first {
                path.move(to: first)
                for point in points.dropFirst() { path.addLine(to: point) }
                path.closeSubpath()
            }
            cover.mask.path = path
        }
        CATransaction.commit()
        covers.removeAll { time >= $0.ends }
        if covers.isEmpty { driver.stop() }
    }
}
