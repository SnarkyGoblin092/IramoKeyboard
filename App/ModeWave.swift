import SwiftUI

/// The wave that carries the Themes screen from light to dark and back: a band of Liquid Glass crosses the screen
/// from left to right, and every preview shows its new look where the band has passed and its old look ahead of it.
///
/// The screen owns the wave (ThemesView) and hands it down in the environment; the previews cut themselves at its
/// front (`revealedByWave`), each from where it is on the screen, so the cut is one straight line down all of them,
/// hidden under the band. `progress` is animated from 0 to 1.
struct ModeWave: Equatable {
    let id: Int
    /// 0: the band is off the left edge; 1: off the right edge.
    var progress: CGFloat
    /// The mode the previews are leaving.
    let oldScheme: ColorScheme
    /// The screen's left edge and width, in the window's coordinates.
    let minX: CGFloat
    let width: CGFloat
    /// When it set off (CACurrentMediaTime), for the keyboard's own layers, which follow it outside SwiftUI.
    let started: CFTimeInterval

    static let duration: TimeInterval = 0.9
    /// The band's width.
    static let band: CGFloat = 96

    /// The wave now crossing the screen, for the code that learns of the new mode outside SwiftUI's updates (the
    /// keyboard's rebuild, a card's picture arriving from the queue).
    static var active: ModeWave?
    static var count = 0

    /// The middle of the band, in the window's coordinates.
    func front(_ progress: CGFloat) -> CGFloat {
        return minX - ModeWave.band / 2 + progress * (width + ModeWave.band)
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

/// The part of a view the wave has passed: everything left of its front. `originX` is the view's left edge in the
/// window.
private struct WavePassed: Shape {
    var progress: CGFloat
    let wave: ModeWave
    let originX: CGFloat

    var animatableData: CGFloat {
        get { return progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let cut = wave.front(progress) - originX
        let width = max(0, min(rect.width, cut - rect.minX))
        return Path(CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height))
    }
}

extension View {
    /// While a wave crosses the screen, shows the view only where it has passed (what is drawn under the view,
    /// its old look, shows ahead of it). Without a wave the view is shown whole.
    func revealedByWave(_ wave: ModeWave?) -> some View {
        return mask {
            if let wave = wave {
                GeometryReader { geometry in
                    WavePassed(progress: wave.progress, wave: wave, originX: geometry.frame(in: .global).minX)
                }
            } else {
                Rectangle()
            }
        }
    }
}

/// The band itself, over the whole screen: a standing wave of Liquid Glass, as wide as ModeWave.band, moving with
/// the wave's front.
struct GlassWaveBand: View {
    let wave: ModeWave

    var body: some View {
        GeometryReader { geometry in
            WaveGlass()
                .frame(width: ModeWave.band, height: geometry.size.height)
                .offset(x: wave.front(wave.progress) - geometry.frame(in: .global).minX - ModeWave.band / 2)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Liquid Glass in the band's shape (a frosted material before iOS 26), with a rim of light on its edges.
private struct WaveGlass: View {
    private let shape = WaveBandShape()

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
                                               startPoint: .leading, endPoint: .trailing)))
    }
}

/// A tall band whose two edges ripple, each in its own rhythm. The edges stay clear of the band's middle, where the
/// previews are cut.
private struct WaveBandShape: Shape {
    func path(in rect: CGRect) -> Path {
        let swing: CGFloat = 12
        let step: CGFloat = 8
        func left(_ y: CGFloat) -> CGFloat {
            return rect.minX + swing + swing * sin(y / 210 * 2 * .pi)
        }
        func right(_ y: CGFloat) -> CGFloat {
            return rect.maxX - swing + swing * sin(y / 270 * 2 * .pi + 1.3)
        }
        var path = Path()
        var y = rect.minY
        path.move(to: CGPoint(x: left(y), y: y))
        while y < rect.maxY {
            y = min(rect.maxY, y + step)
            path.addLine(to: CGPoint(x: left(y), y: y))
        }
        path.addLine(to: CGPoint(x: right(y), y: y))
        while y > rect.minY {
            y = max(rect.minY, y - step)
            path.addLine(to: CGPoint(x: right(y), y: y))
        }
        path.closeSubpath()
        return path
    }
}
