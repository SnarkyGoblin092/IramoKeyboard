import SwiftUI

/// The wave that carries the Themes screen from light to dark and back: a glowing, rainbow-tinted band of Liquid
/// Glass sweeps down the screen as a half circle (its front bulging downward), and every preview shows its new look
/// where the band has passed and its old look below it.
///
/// The screen owns the wave (ThemesView) and hands it down in the environment; the previews cut themselves at its
/// front (`revealedByWave`), each from where it is on the screen, so the cut is one curve across all of them,
/// hidden under the band. `progress` is animated from 0 to 1.
struct ModeWave: Equatable {
    let id: Int
    /// 0: the band is above the top edge; 1: below the bottom edge.
    var progress: CGFloat
    /// The mode the previews are leaving.
    let oldScheme: ColorScheme
    /// The screen's frame, in the window's coordinates.
    let minX: CGFloat
    let minY: CGFloat
    let width: CGFloat
    let height: CGFloat
    /// When the wave sets off (CACurrentMediaTime; a little after it is made), for the keyboard's own layers, which
    /// follow it outside SwiftUI on this same clock.
    let started: CFTimeInterval

    static let duration: TimeInterval = 1.1
    /// The head start the keyboard's layers and SwiftUI's animation both wait for, so they set off together.
    static let lead: TimeInterval = 0.12
    /// The band's thickness.
    static let band: CGFloat = 96

    /// The wave now crossing the screen, for the code that learns of the new mode outside SwiftUI's updates (the
    /// keyboard's rebuild, a card's picture arriving from the queue).
    static var active: ModeWave?
    static var count = 0

    /// The half circle's radius: half the screen's width.
    var radius: CGFloat { return width / 2 }

    /// The height of the cut at the circle's lowest point (the middle of the screen), in the window's coordinates.
    func center(_ progress: CGFloat) -> CGFloat {
        let start = minY - ModeWave.band / 2
        let end = minY + height + radius + ModeWave.band / 2
        return start + progress * (end - start)
    }

    /// The height of the cut at window x.
    func cutY(x: CGFloat, progress: CGFloat) -> CGFloat {
        return center(progress) + ModeWave.arc(dx: x - (minX + radius), radius: radius)
    }

    /// How far the half circle lies above its lowest point at `dx` from the middle.
    static func arc(dx: CGFloat, radius: CGFloat) -> CGFloat {
        return sqrt(max(0, radius * radius - dx * dx)) - radius
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

/// The part of a view the wave has passed: everything above its curved front. `origin` is the view's top left in
/// the window.
private struct WavePassed: Shape {
    var progress: CGFloat
    let wave: ModeWave
    let origin: CGPoint

    var animatableData: CGFloat {
        get { return progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 6
        func cut(_ x: CGFloat) -> CGFloat {
            let y = wave.cutY(x: origin.x + x - rect.minX, progress: progress) - origin.y + rect.minY
            return min(rect.maxY, max(rect.minY, y))
        }
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        var x = rect.minX
        path.addLine(to: CGPoint(x: x, y: cut(x)))
        while x < rect.maxX {
            x = min(rect.maxX, x + step)
            path.addLine(to: CGPoint(x: x, y: cut(x)))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

extension View {
    /// While a wave crosses the screen, shows the view only where it has passed (what is drawn under the view,
    /// its old look, shows below the front). Without a wave the view is shown whole.
    func revealedByWave(_ wave: ModeWave?) -> some View {
        return mask {
            if let wave = wave {
                GeometryReader { geometry in
                    let frame = geometry.frame(in: .global)
                    WavePassed(progress: wave.progress, wave: wave, origin: frame.origin)
                }
            } else {
                Rectangle()
            }
        }
    }
}

/// The band itself, over the whole screen: a half circle of Liquid Glass, as thick as ModeWave.band, moving down
/// with the wave's front.
struct GlassWaveBand: View {
    let wave: ModeWave

    var body: some View {
        GeometryReader { geometry in
            let height = wave.radius + ModeWave.band
            // The band's lowest edge sits half a band under the cut, in the middle.
            WaveGlass()
                .frame(width: wave.width, height: height)
                .offset(x: wave.minX - geometry.frame(in: .global).minX,
                        y: wave.center(wave.progress) + ModeWave.band / 2 - height - geometry.frame(in: .global).minY)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private let rainbow: [Color] = [
    Color(red: 1.0, green: 0.30, blue: 0.35), Color(red: 1.0, green: 0.65, blue: 0.20),
    Color(red: 1.0, green: 0.92, blue: 0.30), Color(red: 0.35, green: 0.90, blue: 0.45),
    Color(red: 0.25, green: 0.75, blue: 1.0), Color(red: 0.55, green: 0.40, blue: 1.0),
    Color(red: 0.95, green: 0.40, blue: 0.85)
]

/// Liquid Glass in the band's shape (a frosted material before iOS 26), tinted with rainbow colors and glowing.
private struct WaveGlass: View {
    private let shape = WaveBandShape()

    var body: some View {
        glass
            .overlay(shape.fill(LinearGradient(colors: rainbow.reversed(), startPoint: .top, endPoint: .bottom))
                .opacity(0.38))
            .overlay(shape.stroke(LinearGradient(colors: rainbow + [rainbow[0]], startPoint: .leading,
                                                 endPoint: .trailing), lineWidth: 2).opacity(0.9))
            .background(shape.fill(LinearGradient(colors: rainbow.reversed(), startPoint: .top, endPoint: .bottom))
                .blur(radius: 18).opacity(0.7))
            .shadow(color: Color.white.opacity(0.55), radius: 14, x: 0, y: 0)
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 0)
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

/// A band in the shape of a half circle's rim, bulging downward: its lower edge is the half circle (the screen's
/// width across), its upper edge the same half circle ModeWave.band higher.
private struct WaveBandShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = rect.width / 2
        let band = ModeWave.band
        let step: CGFloat = 6
        func lower(_ x: CGFloat) -> CGFloat {
            return rect.maxY + ModeWave.arc(dx: x - rect.midX, radius: radius)
        }
        var path = Path()
        var x = rect.minX
        path.move(to: CGPoint(x: x, y: lower(x)))
        while x < rect.maxX {
            x = min(rect.maxX, x + step)
            path.addLine(to: CGPoint(x: x, y: lower(x)))
        }
        while x > rect.minX {
            path.addLine(to: CGPoint(x: x, y: lower(x) - band))
            x = max(rect.minX, x - step)
        }
        path.addLine(to: CGPoint(x: x, y: lower(x) - band))
        path.closeSubpath()
        return path
    }
}
