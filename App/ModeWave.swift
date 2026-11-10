import SwiftUI

/// The wave that carries the app from light to dark and back, or to another theme: a thin, irregular rim spreads out
/// from where the finger touched, and the whole window shows its new look inside it and its old look outside it,
/// bent around the front as by the edge of a lens (WindowWave).
///
/// The screen keeps the running wave (ThemesView) and hands it down in the environment. Nothing is updated for each
/// frame of a wave: whoever draws it (the window's cover, the rim) reads the clock itself, `progress(at:)`, so they
/// are always at the same place.
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
    static let band: CGFloat = 21
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

/// The part of the window the wave has passed: everything inside its irregular circle. `origin` is the view's top
/// left in the window.
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

/// The rims themselves, over the whole window, spreading out with the waves' fronts.
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

/// The wave's front: a rainbow rim with a glow (no glass: only the colours show).
private struct WaveGlass: View {
    let wave: ModeWave
    let progress: CGFloat
    let origin: CGPoint

    let size: CGSize

    /// The rim's centre line lies on the front itself (the outer edge is half a band beyond it).
    private var rim: WaveDiscShape { return WaveDiscShape(wave: wave, progress: progress, origin: origin, grow: -ModeWave.band / 2) }

    /// The front's line at `offset` points from the front (negative: inside), the same all round except that the
    /// rainbow's width swells and narrows as it goes round, and moves, so it never looks like a ruled ring.
    private func line(offset: CGFloat, around base: [CGPoint], from center: CGPoint) -> Path {
        var path = Path()
        for (index, point) in base.enumerated() {
            let angle = Double(index) / Double(base.count) * 2 * .pi
            let swell = 1 + 0.4 * sin(2 * angle + wave.shift) + 0.2 * sin(5 * angle - Double(progress) * 6 + wave.shift * 2)
            let dx = point.x - center.x, dy = point.y - center.y
            let length = max(0.001, hypot(dx, dy))
            let moved = CGPoint(x: point.x + dx / length * offset * CGFloat(swell), y: point.y + dy / length * offset * CGFloat(swell))
            if index == 0 { path.move(to: moved) } else { path.addLine(to: moved) }
        }
        path.closeSubpath()
        return path
    }

    /// A rainbow rim on the front: a spectrum of wide, faint strokes that run into each other (red inside, violet
    /// outside, wider in some places than in others), a thin bright line in its heart with hot places that travel
    /// round it, a hue-shifting wake of colour just inside, and a blue glow outside. The shader (WaveLens.metal) bends
    /// the colours around it. It fades in as the wave sets off and out as it leaves.
    ///
    /// No blur of the whole screen's size: that made every frame slow. The glow and the strokes are a few canvases.
    var body: some View {
        let glowLine = rim.path(in: CGRect(origin: .zero, size: size))
        let palette = WavePalette.of(wave)
        let blue = palette.tint
        let center = CGPoint(x: wave.center.x - origin.x, y: wave.center.y - origin.y)
        let base = wave.outline(progress, relativeTo: origin)
        let fade = Double(min(1, progress / 0.05) * min(1, max(0, (ModeWave.doneShare - progress) / 0.08)))
        let turn = Angle.radians(Double(progress) * 5 + wave.shift)
        // No glass under the rim: only the colours show.
        return Color.clear
            .background(Canvas { context, _ in
                context.opacity = fade
                for stroke in WaveGlass.glow {
                    context.stroke(glowLine, with: .color(blue.opacity(stroke.opacity)), lineWidth: stroke.width)
                }
                // The wake: soft colour that drifts round just inside the front.
                let hues = GraphicsContext.Shading.conicGradient(palette.conic, center: center, angle: turn)
                for (offset, width, opacity) in [(-20.0, 26.0, 0.07), (-13.0, 14.0, 0.10), (-8.0, 6.0, 0.14)] {
                    var layer = context
                    layer.opacity = fade * opacity * (palette.dark ? 3 : 4)
                    layer.stroke(line(offset: CGFloat(offset), around: base, from: center), with: hues, lineWidth: CGFloat(width))
                }
            })
            .overlay(Canvas { context, _ in
                context.opacity = fade
                // Many overlapping wide, faint strokes, so the colours run into each other (a blur, without the cost of
                // blurring the whole screen every frame).
                for band in palette.spectrum {
                    context.stroke(line(offset: band.grow, around: base, from: center),
                                   with: .color(band.color.opacity(palette.bandOpacity)), lineWidth: 5.25)
                }
                // The bright line in its heart, hot in a few places that travel round it.
                let hot = GraphicsContext.Shading.conicGradient(WaveGlass.hot(palette.heart), center: center, angle: turn * -0.7)
                let heart = line(offset: 0, around: base, from: center)
                context.stroke(heart, with: hot, lineWidth: 7)
                context.stroke(heart, with: hot, lineWidth: 1.6)
            }.blendMode(palette.dark ? .plusLighter : .normal))
    }

    /// The heart line's colour (white on dark, deep indigo on light): bright in a few places, faint between.
    private static func hot(_ color: Color) -> Gradient {
        return Gradient(stops: [
            .init(color: color.opacity(0.08), location: 0), .init(color: color.opacity(0.85), location: 0.1),
            .init(color: color.opacity(0.08), location: 0.24), .init(color: color.opacity(0.12), location: 0.5),
            .init(color: color.opacity(0.7), location: 0.63), .init(color: color.opacity(0.08), location: 0.78),
            .init(color: color.opacity(0.08), location: 1)
        ])
    }

    /// The blue glow under the glass, and the shine's own glow of colours over it: widest and faintest first.
    private static let glow: [(width: CGFloat, opacity: Double)] = [(42, 0.05), (28, 0.08), (17, 0.13), (7, 0.22)]
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

/// Carries the whole window across a light / dark or theme change, the navigation bar, the keyboard and every
/// button and label included: a picture of the window as it was is laid over it before the setting changes, and a
/// picture of it as it has become is taken once the change has been drawn. While the wave crosses, the old picture
/// shows outside the front and the new one inside it, the lens (WaveLens.metal) bends both around the front, and the
/// rim is drawn over them. (Pictures, because views the system draws itself, the keys and the switches, cannot be
/// reached by a shader.) Until the new picture is ready, the live window shows inside the front. Nothing under it
/// can be touched while it is out.
@MainActor
enum WindowWave {
    private static var current: (host: UIViewController, model: WindowWaveModel)?
    /// How long after the setting changes the new picture is taken: long enough for everything to have been drawn
    /// anew (the keyboard rebuilds a couple of run-loop turns after the setting changes). The front has barely set off
    /// by then (the curve eases in).
    private static let settle: TimeInterval = 0.1

    static var window: UIWindow? {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
        return windows.first(where: { $0.isKeyWindow }) ?? windows.first
    }

    /// Called as the wave sets off, before the setting changes.
    static func start(for wave: ModeWave) {
        end()
        guard let window = window, let root = window.rootViewController?.view,
              let old = picture(of: root, afterScreenUpdates: false) else { return }
        let model = WindowWaveModel(wave: wave, old: old)
        let host = UIHostingController(rootView: WindowWaveView(model: model))
        host.view.backgroundColor = .clear
        if #available(iOS 16.4, *) { host.safeAreaRegions = [] }
        host.view.frame = window.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(host.view)
        current = (host, model)
        let lifetime = wave.lifetime
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(settle * 1_000_000_000))
            guard current?.model === model else { return }
            // Of the app alone (the root view), not of this cover over it.
            model.new = picture(of: root, afterScreenUpdates: true)
            try? await Task.sleep(nanoseconds: UInt64(max(0, lifetime - settle) * 1_000_000_000))
            if current?.model === model { end() }
        }
    }

    private static func end() {
        current?.host.view.removeFromSuperview()
        current = nil
    }

    private static func picture(of view: UIView, afterScreenUpdates: Bool) -> UIImage? {
        guard view.bounds.width > 0, view.bounds.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = view.window?.screen.scale ?? UIScreen.main.scale
        return UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: afterScreenUpdates)
        }
    }
}

/// The window's two pictures for one wave (WindowWave): the old one at once, the new one once it is drawn.
private final class WindowWaveModel: ObservableObject {
    let wave: ModeWave
    let old: UIImage
    @Published var new: UIImage?

    init(wave: ModeWave, old: UIImage) {
        self.wave = wave
        self.old = old
    }
}

/// The cover over the whole window while a wave crosses it (its coordinates are the window's).
private struct WindowWaveView: View {
    @ObservedObject var model: WindowWaveModel

    var body: some View {
        let wave = model.wave
        let old = model.old
        let new = model.new
        TimelineView(.animation(minimumInterval: ModeWave.frame)) { context in
            let progress = wave.progress(at: context.date)
            ZStack {
                Image(uiImage: old).resizable()
                    .mask(WaveAhead(wave: wave, progress: progress, origin: .zero).fill(style: FillStyle(eoFill: true)))
                if let new = new {
                    Image(uiImage: new).resizable()
                        .mask(WavePassed(wave: wave, progress: progress, origin: .zero))
                }
            }
            .modifier(WindowLens(wave: wave, progress: progress, isOn: new != nil))
        }
        .overlay(GlassWaveBand(waves: [wave]))
        .ignoresSafeArea()
        // Takes every touch while it is out.
        .contentShape(Rectangle())
        .onTapGesture {}
        .gesture(DragGesture())
        .accessibilityHidden(true)
    }
}

/// Bends and splits the colours of both pictures around the front (WaveLens.metal), as light is at the edge of a
/// thick lens. Needs iOS 17; earlier the rim alone is the effect. Only the band around the front is worked on: the
/// shader passes every other point straight through.
private struct WindowLens: ViewModifier {
    let wave: ModeWave
    let progress: CGFloat
    let isOn: Bool

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 17.0, *) {
                content.layerEffect(
                    ShaderLibrary.waveLens(.float2(wave.center), .float(Float(progress)), .float(Float(wave.endRadius)),
                                           .float(Float(wave.shift)), .float(Float(ModeWave.band * 2.0)), .float(24)),
                    maxSampleOffset: CGSize(width: 24, height: 24),
                    isEnabled: isOn && progress > 0 && progress < ModeWave.doneShare)
            } else {
                content
            }
        }
    }
}

/// The colours of a wave's rim: a rainbow, red inside to violet outside, run softly into one another.
private struct WavePalette {
    /// The rim's colours from the inside out, as offsets from the rim's centre line.
    let spectrum: [(grow: CGFloat, color: Color)]
    /// The glow's colour.
    let tint = Color(red: 0.30, green: 0.50, blue: 1.0)
    /// The rainbow turned into a ring of colour, for the wake.
    let conic: Gradient

    private static let stops: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
        (0.85, 0.10, 0.05), (1.0, 0.40, 0.05), (1.0, 0.78, 0.15), (0.30, 0.85, 0.25),
        (0.15, 0.70, 0.85), (0.15, 0.35, 1.0), (0.55, 0.20, 0.95)
    ]
    /// How strongly each band is drawn.
    let bandOpacity: Double
    let heart: Color
    let dark: Bool
    private static let darkMode = WavePalette(dark: true)
    private static let lightMode = WavePalette(dark: false)

    /// Going to dark: light that adds to the dark, pale and glowing. Going to light: deeper, truer inks laid over
    /// the light (light added to light would not show).
    static func of(_ wave: ModeWave) -> WavePalette { return wave.newScheme == .dark ? darkMode : lightMode }

    private init(dark: Bool) {
        self.dark = dark
        bandOpacity = dark ? 0.2 : 0.3
        heart = dark ? .white : Color(red: 0.30, green: 0.30, blue: 0.80)
        let count = 15
        var bands: [(grow: CGFloat, color: Color)] = []
        for index in 0..<count {
            let t = CGFloat(index) / CGFloat(count - 1) * CGFloat(WavePalette.stops.count - 1)
            let low = min(WavePalette.stops.count - 2, Int(t)), f = t - CGFloat(low)
            let a = WavePalette.stops[low], b = WavePalette.stops[low + 1]
            // Centred on the front: from 8 points inside it to 8 beyond it.
            // Paled a little toward white, so the colours are soft.
            func pale(_ v: CGFloat) -> CGFloat { return dark ? v + (1 - v) * 0.3 : v * 0.88 }
            bands.append((-8.25 + CGFloat(index) * 1.18,
                          Color(red: pale(a.r + (b.r - a.r) * f), green: pale(a.g + (b.g - a.g) * f), blue: pale(a.b + (b.b - a.b) * f))))
        }
        spectrum = bands
        var ring = WavePalette.stops.map { Color(red: $0.r, green: $0.g, blue: $0.b) }
        ring.append(ring[0])
        conic = Gradient(colors: ring)
    }
}
