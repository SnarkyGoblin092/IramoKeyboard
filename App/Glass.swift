import SwiftUI

// MARK: - Liquid Glass look
//
// Every screen sits on the keybed (a field of faint keys in the accent colour), and its cards and controls are the
// system's own Liquid Glass on top of it (`glassEffect`, iOS 26 and later; a frosted material before that). Nothing
// is painted over the glass: its rim, its light and how clear or tinted it is are the system's, so it follows the
// Liquid Glass setting of the phone (iOS 27's slider) like every system control.

/// What the glass has behind it: the grouped background, a wash of the accent from the top, and the keybed. Glass
/// bends what is under it, so it needs edges to bend: over the keys its rims show the refraction that a plain blur
/// of colour never does.
struct GlassBackdrop: View {
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let accent = Color.currentAccent(name: accentName, hex: accentHex)
        let dark = scheme == .dark
        return ZStack {
            Color(.systemGroupedBackground)
            LinearGradient(colors: [accent.opacity(dark ? 0.34 : 0.22),
                                    accent.hueShifted(by: 0.07).opacity(dark ? 0.12 : 0.08),
                                    Color.clear],
                           startPoint: .topLeading, endPoint: .bottom)
            Keybed(accent: accent, dark: dark)
        }
        // A new accent fades in over the old one.
        .animation(AccentTint.fade, value: accentName + accentHex)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Rows of large, faint keys, staggered like a keyboard's and tilted a little, fading out down the screen.
private struct Keybed: View, Animatable {
    // The accent as numbers, so a new accent is eased in by the same animation as the wash above the keys (a Canvas
    // would otherwise take the new colour at once).
    var red: Double
    var green: Double
    var blue: Double
    let dark: Bool

    init(accent: Color, dark: Bool) {
        let resolved = UIColor(accent).resolvedColor(with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.dark = dark
    }

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, Double> {
        get { return AnimatablePair(AnimatablePair(red, green), blue) }
        set {
            red = newValue.first.first
            green = newValue.first.second
            blue = newValue.second
        }
    }

    var body: some View {
        let accent = Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
        return Canvas { context, size in
            guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return }
            let key: CGFloat = 60
            let pitch: CGFloat = key + 11
            let stagger: [CGFloat] = [0, 0.5, 0.25, 0.75]
            // Turned about the middle; the rows reach past the edges so the corners stay covered.
            let reach: CGFloat = max(size.width, size.height) * 0.7
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.rotate(by: .degrees(-11))
            context.translateBy(x: -size.width / 2, y: -size.height / 2)
            let rows = Int((size.height + reach) / pitch) + 2
            let columns = Int((size.width + reach) / pitch) + 2
            let base: Double = dark ? 0.10 : 0.07
            for row in 0..<rows {
                let y: CGFloat = CGFloat(row) * pitch - reach / 2
                let depth: Double = Double(min(1, max(0, y / max(size.height, 1))))
                let strength: Double = base * (1 - 0.85 * depth)
                if strength < 0.004 { continue }
                let shift: CGFloat = stagger[row % 4] * pitch
                for column in 0..<columns {
                    let x: CGFloat = CGFloat(column) * pitch - reach / 2 + shift
                    let path = Path(roundedRect: CGRect(x: x, y: y, width: key, height: key), cornerRadius: 15,
                                    style: .continuous)
                    context.fill(path, with: .color(accent.opacity(strength)))
                    context.stroke(path, with: .color(Color.white.opacity(strength * (dark ? 0.8 : 1.8))), lineWidth: 1)
                }
            }
        }
    }
}

/// A list row's background: real Liquid Glass over the backdrop (frosted glass before iOS 26), the same on every
/// list of the app (settings, languages, learned words, shortcuts).
struct GlassRowFill: View {
    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: Rectangle())
        } else {
            Rectangle().fill(.thinMaterial)
        }
        #else
        Rectangle().fill(.thinMaterial)
        #endif
    }
}

extension Color {
    /// The same colour turned round the colour wheel (a share of a full turn).
    func hueShifted(by turn: Double) -> Color {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return self }
        var shifted = (hue + CGFloat(turn)).truncatingRemainder(dividingBy: 1)
        if shifted < 0 { shifted += 1 }
        return Color(hue: Double(shifted), saturation: Double(saturation), brightness: Double(brightness), opacity: Double(alpha))
    }
}

/// The rim of a frosted card before iOS 26. Real Liquid Glass has a rim of its own, lit by the system (and dimmed
/// or cleared by the phone's Liquid Glass setting): nothing is drawn over it.
private struct GlassEdge<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.colorScheme) private var scheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content.overlay(
                shape.strokeBorder(Color.white.opacity(scheme == .dark ? 0.18 : 0.5), lineWidth: 0.6)
                    .allowsHitTesting(false))
        }
    }
}

/// See `glassTile`: the accent is the user's (the Themes screen), read here so every tile follows it.
private struct GlassTile<S: Shape>: ViewModifier {
    let shape: S
    let isOn: Bool
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex

    func body(content: Content) -> some View {
        content.glassShape(shape, tint: isOn ? Color.currentAccent(name: accentName, hex: accentHex) : nil, interactive: true)
    }
}

#if compiler(>=6.2)
@available(iOS 26.0, *)
private func makeGlass(tint: Color?, interactive: Bool) -> Glass {
    var glass = Glass.regular
    if let tint = tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}
#endif

/// A blur behind the title at the top of a tab: full strength down to half its height, then fading to nothing
/// over the lower half, so the list has no hard edge under it. A real variable blur, with no grey tint.
struct TitleBlur: View {
    var body: some View {
        GeometryReader { proxy in
            // Solid down to the bottom of the title (the bar's bottom edge), then 48 pt of fade below it.
            let top = proxy.safeAreaInsets.top
            VariableBlurView(solid: top / (top + 48))
                .frame(height: top + 48)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

/// The system's blur with its amount varying along a mask (the blur filter UIKit's own bars use), and its tint
/// layers taken away. If the filter is not there, a plain blur faded out by a gradient instead.
private struct VariableBlurView: UIViewRepresentable {
    /// The share of the height (from the top) at full strength.
    let solid: CGFloat

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        guard let backdrop = view.subviews.first,
              let filterClass = NSClassFromString("CAFilter") as? NSObject.Type,
              let made = filterClass.perform(NSSelectorFromString("filterWithType:"), with: "variableBlur"),
              let filter = made.takeUnretainedValue() as? NSObject,
              let mask = VariableBlurView.maskImage(solid: solid) else {
            view.layer.mask = VariableBlurView.fadeMask(for: view.bounds, solid: solid)
            return
        }
        filter.setValue(10, forKey: "inputRadius")
        filter.setValue(mask, forKey: "inputMaskImage")
        filter.setValue(true, forKey: "inputNormalizeEdges")
        backdrop.layer.filters = [filter]
        // The effect's grey tint and edge layers.
        for tint in view.subviews.dropFirst() { tint.alpha = 0 }
    }

    /// The blur's amount along the view: all of it down to `solid`, none at the bottom (alpha of the image).
    private static func maskImage(solid: CGFloat) -> CGImage? {
        let size = CGSize(width: 1, height: 256)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                            locations: [0, solid, 1]) else { return }
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
        return image.cgImage
    }

    private static func fadeMask(for bounds: CGRect, solid: CGFloat) -> CALayer {
        let layer = CAGradientLayer()
        layer.frame = bounds
        layer.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        layer.locations = [0, NSNumber(value: Double(solid)), 1]
        return layer
    }
}

extension View {
    /// A piece of Liquid Glass in the shape (a frosted material before iOS 26), optionally tinted, and answering
    /// touches when `interactive`. The sliders and buttons use it.
    @ViewBuilder
    func glassShape<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(makeGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            self.background(shape.fill(.thinMaterial)).background(shape.fill(tint ?? .clear))
                .overlay(shape.stroke(Color.white.opacity(0.3), lineWidth: 0.5))
        }
        #else
        self.background(shape.fill(.thinMaterial)).background(shape.fill(tint ?? .clear))
            .overlay(shape.stroke(Color.white.opacity(0.3), lineWidth: 0.5))
        #endif
    }

    /// A tile or pill button's surface (the tab bars, option cards, symbol chips...): Liquid Glass that answers
    /// the finger, tinted with the app's accent when it is the chosen one (`isOn`).
    func glassTile<S: Shape>(_ shape: S, isOn: Bool) -> some View {
        return modifier(GlassTile(shape: shape, isOn: isOn))
    }

    func glassEdge<S: InsettableShape>(_ shape: S) -> some View {
        return modifier(GlassEdge(shape: shape))
    }

    /// The app's typeface: the system's rounded design where the system has it (iOS 16.1 and later).
    @ViewBuilder
    func roundedType() -> some View {
        if #available(iOS 16.1, *) { self.fontDesign(.rounded) } else { self }
    }

    /// A tab's navigation bar: the title always shown, with no bar behind it that comes in as the list scrolls.
    @ViewBuilder
    func quietNavBar() -> some View {
        let base = self
            .toolbarBackground(.hidden, for: .navigationBar)
            .overlay(alignment: .top) { TitleBlur() }
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            base.scrollEdgeEffectHidden(true, for: .top)
        } else {
            base
        }
        #else
        base
        #endif
    }

    /// A screen of the app: its list or scroll view on the glass backdrop.
    func glassScreen() -> some View {
        return self
            .scrollContentBackground(.hidden)
            .background(GlassBackdrop())
    }

    /// The rows of a list section, drawn as glass.
    @ViewBuilder
    func glassRows() -> some View {
        // Separators run the full width of the list, not inset from the leading edge.
        if #available(iOS 16.0, *) {
            self.listRowBackground(GlassRowFill())
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        } else {
            self.listRowBackground(GlassRowFill())
        }
    }
}

/// A search field drawn as a capsule of Liquid Glass (a frosted material before iOS 26), pinned above a screen.
struct GlassSearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("Clear"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassShape(Capsule(), interactive: true)
    }
}

/// A button style with no press effect at all (a row that swipes as well as taps: no lens of glass lights up under
/// the finger while it slides).
struct NoPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.rowTapArea()
    }
}

extension View {
    /// The screen's search field, in glass: above the content, in place of the system's `searchable` bar.
    func glassSearchable(text: Binding<String>, prompt: String) -> some View {
        return self.safeAreaInset(edge: .top, spacing: 0) {
            GlassSearchField(text: text, prompt: prompt)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
        }
    }
}

private struct ScrollOffsetReportKey: EnvironmentKey {
    static let defaultValue: ((CGFloat) -> Void)? = nil
}

extension EnvironmentValues {
    /// Called with how far a GlassList is scrolled (0 at its top, negative when pulled down past it).
    var scrollOffsetReport: ((CGFloat) -> Void)? {
        get { return self[ScrollOffsetReportKey.self] }
        set { self[ScrollOffsetReportKey.self] = newValue }
    }
}

/// Reports a scroll view's offset to `scrollOffsetReport` (iOS 18 and later).
private struct ReportScrollOffset: ViewModifier {
    let report: ((CGFloat) -> Void)?
    /// The finger is on the list, dragging it (not a fling coming to rest, nor the bounce back at the top).
    @State private var dragging = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if let report = report, #available(iOS 18.0, *) {
            content
                .onScrollPhaseChange { _, phase in dragging = phase == .interacting }
                .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y + $0.contentInsets.top },
                                        action: { _, new in
                    // Past the top only counts while the finger is pulling.
                    report(new < 0 && !dragging ? 0 : new)
                })
        } else {
            content
        }
    }
}

/// The rounded corner of the app's cards: larger on iOS 26, as the system's own.
enum GlassMetrics {
    static var cardRadius: CGFloat {
        if #available(iOS 26, *) { return 26 }
        return 14
    }
}

// MARK: - Controls on glass screens

/// A slider bound straight to a stored value: it follows the value when something else changes it (a preset), and
/// saves as the finger moves, so the previews above it change while dragging.
struct GlassSlider: View {
    let title: String
    let symbol: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String
    /// Set for a slider that is felt (the vibration's): called with the new value at each step in place of the
    /// click.
    let onStep: ((Double) -> Void)?

    init(title: String, symbol: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double,
         onStep: ((Double) -> Void)? = nil, format: @escaping (Double) -> String) {
        self.title = title
        self.symbol = symbol
        self._value = value
        self.range = range
        self.step = step
        self.onStep = onStep
        self.format = format
    }

    var body: some View {
        ValueBar(title: title, symbol: symbol, value: $value, range: range, step: step, format: format, onStep: onStep)
    }
}

/// The app's slider, its name and value written over it. On iOS 26 and later the system's Liquid Glass slider; before
/// that drawn by hand (a glass groove filling with the accent and a glass bead), as the older system Slider's own
/// haptics (a hard knock at either end) came on top of the app's light click per step. Drag sideways anywhere on the
/// drawn one; vertical drags still scroll the screen.
struct ValueBar: View {
    let title: String
    var symbol: String? = nil
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String
    /// Called with true when a drag starts and false when it ends.
    var onEditingChanged: (Bool) -> Void = { _ in }
    /// A felt setting (the vibration): called with the new value at each step instead of the click, so each step
    /// plays the setting itself (the iOS 26 system slider still adds its own knock at either end).
    var onStep: ((Double) -> Void)? = nil

    @Environment(\.isEnabled) private var isEnabled
    /// Whether the current drag is sideways (decided once, at its start); nil until it is known.
    @State private var horizontal: Bool?
    @State private var startValue: Double = 0

    private var span: Double { return max(range.upperBound - range.lowerBound, .ulpOfOne) }

    private func snapped(_ raw: Double) -> Double {
        let clamped = min(max(raw, range.lowerBound), range.upperBound)
        guard step > 0 else { return clamped }
        let steps = ((clamped - range.lowerBound) / step).rounded()
        return min(range.lowerBound + steps * step, range.upperBound)
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            systemBar
        } else {
            drawnBar
        }
    }

    /// The name, and the value on a capsule of the accent.
    private var header: some View {
        HStack(spacing: 8) {
            if let symbol = symbol {
                Image(systemName: symbol).foregroundStyle(.tint)
            }
            Text(title).font(.subheadline).lineLimit(1).minimumScaleFactor(0.8)
                .foregroundColor(isEnabled ? .primary : .secondary)
            Spacer(minLength: 8)
            Text(format(value))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.accentColor.opacity(0.2)))
        }
    }

    /// iOS 26 and later: the system's Liquid Glass slider, whose knob turns into a lens of glass while it is dragged.
    /// It snaps to the steps itself (the system's step marks would crowd the track) with the app's click per step.
    @available(iOS 26.0, *)
    private var systemBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Slider(value: Binding(get: { value }, set: { raw in
                let next = snapped(raw)
                if abs(next - value) > step * 0.01 {
                    value = next
                    if let onStep = onStep { onStep(next) } else { Feedback.tick() }
                }
            }), in: range, onEditingChanged: onEditingChanged)
            .tint(Color.accentColor)
            .accessibilityLabel(title)
            .accessibilityValue(format(value))
        }
        .frame(height: 72)
        .padding(.vertical, 2)
    }

    private var drawnBar: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let fraction = CGFloat(min(max((value - range.lowerBound) / span, 0), 1))
            let thumb: CGFloat = 30
            let travel = max(0, width - thumb)
            let edge = thumb / 2 + travel * fraction
            VStack(alignment: .leading, spacing: 8) {
                header
                // A glass groove with the accent filling it, and a glass bead on the end of the fill.
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.clear).frame(height: 14)
                        .glassShape(Capsule())
                    Capsule()
                        .fill(LinearGradient(colors: [Color.accentColor.opacity(0.55), Color.accentColor],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, edge), height: 8)
                        .padding(.leading, 3)
                        .opacity(isEnabled ? 1 : 0.5)
                    Circle()
                        .fill(Color.clear)
                        .frame(width: thumb, height: thumb)
                        .glassShape(Circle(), tint: Color.white.opacity(0.35), interactive: true)
                        .overlay(Circle().fill(Color.accentColor).frame(width: 8, height: 8))
                        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                        .offset(x: travel * fraction)
                }
                .frame(height: thumb)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            // A UIKit pan that only begins on a sideways drag, so a vertical drag starting on the bar scrolls the list.
            .overlay(HorizontalPan(
                began: {
                    guard isEnabled else { return }
                    horizontal = true
                    startValue = value
                    onEditingChanged(true)
                },
                changed: { translation in
                    guard isEnabled, horizontal == true, width > 0 else { return }
                    let next = snapped(startValue + Double(translation / max(width - thumb, 1)) * span)
                    if abs(next - value) > step * 0.01 {
                        value = next
                        // Once per step; nothing more at either end.
                        if let onStep = onStep { onStep(next) } else { Feedback.tick() }
                    }
                },
                ended: {
                    if horizontal == true { onEditingChanged(false) }
                    horizontal = nil
                }))
        }
        .frame(height: 72)
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { direction in
            let delta = step > 0 ? step : span / 20
            switch direction {
            case .increment: value = snapped(value + delta)
            case .decrement: value = snapped(value - delta)
            @unknown default: break
            }
        }
    }
}

/// A pan recognizer that begins only when the drag starts out sideways, leaving vertical drags to the scroll view.
private struct HorizontalPan: UIViewRepresentable {
    let began: () -> Void
    let changed: (CGFloat) -> Void
    let ended: () -> Void

    func makeCoordinator() -> Coordinator { return Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: HorizontalPan?

        @objc func pan(_ recognizer: UIPanGestureRecognizer) {
            guard let parent = parent else { return }
            switch recognizer.state {
            case .began: parent.began(); parent.changed(recognizer.translation(in: recognizer.view).x)
            case .changed: parent.changed(recognizer.translation(in: recognizer.view).x)
            case .ended, .cancelled, .failed: parent.ended()
            default: break
            }
        }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}

/// What the sliders show: real sizes on this device instead of shares and multipliers.
enum DeviceMetrics {
    /// The screen's width held upright, in points (the keyboard's width in portrait).
    static var portraitWidth: Double {
        let bounds = UIScreen.main.bounds
        return Double(min(bounds.width, bounds.height))
    }

    /// The previews' keyboard width: the screen's short side (the previews are always upright).
    static var keyboardWidth: Double { return portraitWidth }

    static func points(_ value: Double) -> String {
        return "\(Int(value.rounded())) pt"
    }

    /// A strength with no unit of its own (how much a feature acts), in words.
    static func level(_ value: Double, in range: ClosedRange<Double>) -> String {
        let share = (value - range.lowerBound) / max(range.upperBound - range.lowerBound, .ulpOfOne)
        let names = [tr("Off"), tr("Faint"), tr("Light"), tr("Medium"), tr("Strong"), tr("Full")]
        if share <= 0.001 && range.lowerBound <= 0 { return names[0] }
        return names[1 + min(4, max(0, Int(share * 5)))]
    }
}

/// An option toggle with a title and a line of explanation, for the glass cards.
struct GlassToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    /// A feature some languages can't use: greyed out when none of the enabled languages can, with a note naming
    /// the ones that can't.
    let feature: LanguageFeature?
    /// A tap anywhere on the row flips it (the row itself takes the tap, not only the switch).
    let tapsAnywhere: Bool
    @ObservedObject private var languages = EnabledLanguages.shared
    @Environment(\.isEnabled) private var isEnabled

    init(title: String, subtitle: String, isOn: Binding<Bool>, feature: LanguageFeature? = nil, tapsAnywhere: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.feature = feature
        self.tapsAnywhere = tapsAnywhere
    }

    private var unavailable: Bool { return feature.map { languages.lacking($0).all } ?? false }

    private var label: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
            Text(subtitle).font(.footnote).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let feature = feature { FeatureNote(feature) }
        }
    }

    var body: some View {
        Group {
            if tapsAnywhere {
                // The row is one button: a single tap flips it at once (a list row's own switch can need a press and hold).
                Button { isOn.toggle() } label: {
                    HStack(spacing: 12) {
                        label.frame(maxWidth: .infinity, alignment: .leading)
                        // The switch takes its own touches too, so it shows its glass while held and slid.
                        Toggle("", isOn: $isOn).labelsHidden()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityRepresentation { Toggle(isOn: $isOn) { label } }
            } else {
                Toggle(isOn: $isOn) { label }
            }
        }
        .onChange(of: isOn) { _ in Feedback.tick() }
        .disabled(unavailable)
        .opacity(unavailable || !isEnabled ? 0.45 : 1)
    }
}

/// Named presets as the system's segmented control. `selected` is the preset the current values match (nil:
/// none, the user's own mix, and no segment is lit).
struct SegmentedChoice: View {
    var title: String? = nil
    let names: [String]
    let selected: Int?
    /// Off where choosing plays a haptic of its own (the Haptics screen's feels).
    var knock = true
    let choose: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title).font(.subheadline).foregroundColor(.secondary)
            }
            Picker(title ?? tr("Preset"), selection: Binding(get: { selected ?? -1 }, set: { index in
                guard index != selected else { return }
                if knock { Feedback.choose() }
                choose(index)
            })) {
                ForEach(names.indices, id: \.self) { index in
                    Text(names[index]).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Glass lists

/// A settings list. With real Liquid Glass (iOS 26 and later) every section is one rounded piece of glass with its
/// rows inside, like the system's own glass cards; a List can only give each row its own background, which shows
/// as a stack of separate panes. Earlier systems keep the inset grouped List with frosted rows (glassRows).
/// Takes the same `Section { } header: { } footer: { }` content as a List.
struct GlassList<Content: View>: View {
    private let content: Content
    /// The screen this list is on (the settings search takes the user to a row of it: SearchFocus).
    @Environment(\.searchScope) private var scope
    @Environment(\.scrollOffsetReport) private var scrollReport
    /// A setting picked in the search is on this screen: every card is built at once, so its row can be scrolled to.
    /// (Decided when the list first appears, and kept: switching would build every row again.)
    @State private var eager: Bool

    /// `eager`: every card is built at once (a short screen, so any of its rows can be scrolled to); nil decides
    /// by whether the search is taking the user to a row.
    init(eager: Bool? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
        self._eager = State(initialValue: eager ?? (SearchFocus.shared.request != nil))
    }

    var body: some View {
        ScrollViewReader { proxy in
            lists
                .onAppear { SearchFocus.shared.consume(in: scope, proxy: proxy) }
        }
    }

    @ViewBuilder private var lists: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            ScrollView {
                if eager {
                    VStack(alignment: .leading, spacing: 0) { cards }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                } else {
                    // Lazy: a long screen (the Effects screen's hundred-odd cards) only builds the cards on screen.
                    LazyVStack(alignment: .leading, spacing: 0) { cards }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
            }
            .environment(\.inGlassCards, true)
            .modifier(ReportScrollOffset(report: scrollReport))
            .buttonStyle(GlassPressStyle())   // a press on any row lights a lens of glass under it
        } else {
            list
        }
        #else
        list
        #endif
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private var cards: some View {
        Group(sections: content) { sections in
            ForEach(sections) { section in
                GlassCardSection(section: section)
            }
        }
    }
    #endif

    private var list: some View {
        List { content }
            .listStyle(.insetGrouped)
            .buttonStyle(GlassPressStyle())
    }
}

#if compiler(>=6.2)
/// One section of a GlassList: its header, its rows in a glass card, its footer.
@available(iOS 26.0, *)
private struct GlassCardSection: View {
    let section: SectionConfiguration

    var body: some View {
        // Rows marked glassOutsideCard (the app logo) stand on the backdrop; the rows between them share a card.
        let runs = Self.runs(Array(section.content))
        VStack(alignment: .leading, spacing: 0) {
            if !section.header.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(section.header) { $0 }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
            VStack(spacing: 12) {
                ForEach(runs) { run in
                    if run.outside {
                        ForEach(run.rows) { $0 }
                    } else {
                        card(run.rows)
                    }
                }
            }
            if !section.footer.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(section.footer) { $0 }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }
        }
        .padding(.top, section.header.isEmpty ? 18 : 26)
    }

    private func card(_ rows: [Subview]) -> some View {
        let shape = RoundedRectangle(cornerRadius: GlassMetrics.cardRadius, style: .continuous)
        // By the rows' own identity, not by position: a row that is deleted must not leave a stale index behind.
        let lastID = rows.last?.id
        return VStack(spacing: 0) {
            ForEach(rows) { row in
                if row.containerValues.glassBareRow {
                    row
                } else {
                    row.glassRowPadding()
                }
                if row.id != lastID {
                    Divider()
                }
            }
        }
        .clipShape(shape)   // a row's Delete button keeps the card's corners
        .glassEffect(.regular, in: shape)
        .glassEdge(shape)
    }

    /// A stretch of a section's rows that share a card (or stand outside one). It is known by its place among
    /// the section's runs, not by its first row: named after its first row, a card whose first row was deleted
    /// became another card, so the whole card was taken down and built again in the middle of the deletion, with
    /// the rows that stayed alive in both for a moment.
    private struct Run: Identifiable {
        let id: Int
        var outside: Bool
        var rows: [Subview]
    }

    private static func runs(_ rows: [Subview]) -> [Run] {
        var runs: [Run] = []
        for row in rows {
            let outside = row.containerValues.glassOutsideCard
            if !outside, let last = runs.last, !last.outside {
                runs[runs.count - 1].rows.append(row)
            } else {
                runs.append(Run(id: runs.count, outside: outside, rows: [row]))
            }
        }
        return runs
    }
}

@available(iOS 26.0, *)
extension ContainerValues {
    /// The row pads itself (SwipeToDeleteRow), so its Delete button reaches the card's edges.
    @Entry var glassBareRow: Bool = false
    /// The row stands on the backdrop rather than in a card (a List row with a clear background).
    @Entry var glassOutsideCard: Bool = false
}
#endif

private struct InGlassCardsKey: EnvironmentKey {
    static let defaultValue = false
}

private struct SwipeFadeKey: EnvironmentKey {
    static let defaultValue: Double = 1
}

extension EnvironmentValues {
    /// 1 at rest, down to 0 as a swipe-to-delete row's Delete button grows: the text under the button fades with it.
    var swipeFade: Double {
        get { return self[SwipeFadeKey.self] }
        set { self[SwipeFadeKey.self] = newValue }
    }
}

extension EnvironmentValues {
    /// Inside a GlassList drawn as glass cards (a List draws its own disclosure arrows and swipe actions).
    var inGlassCards: Bool {
        get { return self[InGlassCardsKey.self] }
        set { self[InGlassCardsKey.self] = newValue }
    }
}

extension View {
    /// A card row's insets and height, like a List row's.
    func glassRowPadding() -> some View {
        return self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 48)
    }

    /// A row that stands on the backdrop, without a card (clear in a List).
    @ViewBuilder
    func glassOutsideCard() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.listRowBackground(Color.clear).containerValue(\.glassOutsideCard, true)
        } else {
            self.listRowBackground(Color.clear)
        }
        #else
        self.listRowBackground(Color.clear)
        #endif
    }

    /// Swipe the row left to delete it: on the glass cards the red Delete button grows inside the row itself
    /// (SwipeToDeleteRow); in a List, the system's swipe action.
    @ViewBuilder
    func swipeToDelete(enabled: Bool = true, perform: @escaping () -> Void) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            SwipeToDeleteRow(canDelete: enabled, onDelete: perform) { self.glassRowPadding() }
                .containerValue(\.glassBareRow, true)
        } else {
            listSwipeToDelete(enabled: enabled, perform: perform)
        }
        #else
        listSwipeToDelete(enabled: enabled, perform: perform)
        #endif
    }

    private func listSwipeToDelete(enabled: Bool, perform: @escaping () -> Void) -> some View {
        return self.swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if enabled {
                Button(role: .destructive, action: perform) { Label(tr("Delete"), systemImage: "trash") }
            }
        }
    }
}

/// The app's switch. From iOS 26 the system's own Liquid Glass switch in the accent colour: its knob turns into a
/// drop of glass while it slides or is held, as in the system's settings. Before that, a glass groove that fills with
/// the accent when on and a frosted bead that stretches as it slides across. Every Toggle in the app takes it
/// (ContentView sets it on the whole app).
struct GlassSwitchStyle: ToggleStyle {
    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26.0, *) {
            NativeGlassSwitch(configuration: configuration)
        } else {
            drawnSwitch(configuration)
        }
    }

    private func drawnSwitch(_ configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                configuration.label.frame(maxWidth: .infinity, alignment: .leading)
                GlassSwitchKnob(isOn: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "1" : "0")
        .modifier(SwitchTrait())
    }
}

/// The system's switch (Liquid Glass on iOS 26 and later), lit with the accent.
@available(iOS 26.0, *)
private struct NativeGlassSwitch: View {
    let configuration: ToggleStyleConfiguration
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex

    var body: some View {
        Toggle(configuration)
            .toggleStyle(.switch)
            .tint(Color.currentAccent(name: accentName, hex: accentHex))
    }
}

private struct SwitchTrait: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.accessibilityAddTraits(.isToggle)
        } else {
            content.accessibilityAddTraits(.isButton)
        }
    }
}

/// The drawn switch (before iOS 26): the groove and the bead, which stretches while it slides.
private struct GlassSwitchKnob: View {
    let isOn: Bool
    @Environment(\.isEnabled) private var isEnabled
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @State private var stretched = false

    var body: some View {
        let accent = Color.currentAccent(name: accentName, hex: accentHex)
        let height: CGFloat = 27
        let bead: CGFloat = stretched ? 36 : height
        ZStack(alignment: .leading) {
            Capsule().fill(Color.clear).frame(width: 52, height: 32)
                .glassShape(Capsule(), tint: isOn ? accent.opacity(0.85) : nil)
            Capsule().fill(Color.clear).frame(width: bead, height: height)
                .glassShape(Capsule(), tint: Color.white.opacity(0.4), interactive: true)
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1.5)
                .offset(x: isOn ? 52 - bead - 2.5 : 2.5)
        }
        .frame(width: 52, height: 32)
        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: isOn)
        .animation(.spring(response: 0.22, dampingFraction: 0.6), value: stretched)
        .onChange(of: isOn) { _ in
            stretched = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { stretched = false }
        }
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityHidden(true)
    }
}

/// A row showing the current choice that opens a glass screen to pick another (instead of a system menu, whose popup
/// is drawn over the pinned keyboard, or a system selection list, which has neither the glass nor the backdrop).
struct GlassChoiceLink<Value: Hashable>: View {
    let title: String
    let symbol: String
    let options: [(value: Value, name: String)]
    let selected: Value?
    /// What the row says when nothing in `options` is selected (a mix of the user's own).
    var otherName: String? = nil
    let choose: (Value) -> Void

    private var currentName: String {
        return options.first { $0.value == selected }?.name ?? otherName ?? ""
    }

    var body: some View {
        NavigationLink {
            GlassChoiceScreen(title: title, options: options, selected: selected, choose: choose)
        } label: {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                Text(currentName).foregroundColor(.secondary)
                DisclosureChevron()
            }
            .foregroundColor(.primary)
            .contentShape(Rectangle())
        }
    }
}

/// The screen of a GlassChoiceLink: the choices as glass rows on the app's backdrop, a tick on the chosen one.
private struct GlassChoiceScreen<Value: Hashable>: View {
    let title: String
    let options: [(value: Value, name: String)]
    let selected: Value?
    let choose: (Value) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GlassList {
            Section {
                ForEach(options.indices, id: \.self) { index in
                    Button {
                        Feedback.choose()
                        choose(options[index].value)
                        dismiss()
                    } label: {
                        HStack {
                            Text(options[index].name).foregroundColor(.primary)
                            Spacer()
                            if options[index].value == selected {
                                Image(systemName: "checkmark").font(.body.weight(.semibold))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
            .glassRows()
        }
        .glassScreen()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The disclosure arrow of a NavigationLink row on the glass cards (a List draws its own).
struct DisclosureChevron: View {
    @Environment(\.inGlassCards) private var inGlassCards

    var body: some View {
        if inGlassCards {
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
    }
}

#if compiler(>=6.2)
/// A row that slides left to show a red Delete button inside the row itself; a long swipe deletes at once.
@available(iOS 26.0, *)
private struct SwipeToDeleteRow<Content: View>: View {
    let canDelete: Bool
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var settled: CGFloat = 0
    @State private var deleting = false
    private let buttonWidth: CGFloat = 84
    /// How far the Delete button may grow: a long swipe that reaches it deletes at once.
    private let maxReveal: CGFloat = 200
    private let settle = Animation.spring(response: 0.35, dampingFraction: 0.86)

    var body: some View {
        // The row stays put (the name never slides off screen); the Delete button grows in from the right edge.
        // A row can fade its trailing text (swipeFades) as the button grows over it.
        let fade = 1 - min(1, max(0, -offset / 48))
        return content()
            .environment(\.swipeFade, fade)
            .contentShape(Rectangle())   // the card's glass shows through; the whole row still takes taps
            .onTapGesture { close() }
            .overlay(alignment: .trailing) {
                Button(action: delete) {
                    Text(tr("Delete"))
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(width: max(0, -offset))
                        .frame(maxHeight: .infinity)
                        .background(Color.red)
                        .clipped()
                }
                .buttonStyle(.plain)
                .allowsHitTesting(offset < 0)
            }
            // A UIKit pan that only begins on a sideways swipe: a SwiftUI drag here takes the vertical drags from
            // the scroll view too (iOS 18 and later), and the list would not scroll.
            .gesture(SidewaysPan(enabled: canDelete, changed: changed, ended: ended))
    }

    private func changed(_ dx: CGFloat) {
        guard !deleting else { return }
        let target = min(0, settled + dx)
        // Past the full-delete point the button resists instead of stopping dead.
        let resisted = target < -maxReveal ? -maxReveal + (target + maxReveal) * 0.25 : target
        if (offset > -maxReveal) != (resisted > -maxReveal) { Feedback.threshold() }   // crossing it
        offset = resisted
    }

    private func ended(_ dx: CGFloat, _ velocity: CGFloat) {
        guard !deleting else { return }
        let end = min(0, settled + dx)
        if end <= -maxReveal {
            delete()
            return
        }
        // A quick flick counts as far as it was heading.
        let heading = min(0, settled + dx + velocity * 0.2)
        let open = min(end, heading) < -buttonWidth / 2
        withAnimation(settle) { offset = open ? -buttonWidth : 0 }
        settled = open ? -buttonWidth : 0
    }

    private func close() {
        guard offset != 0 else { return }
        withAnimation(settle) { offset = 0 }
        settled = 0
    }

    private func delete() {
        // Once only: removing the row cancels its pan, which reports the end of the drag again (a full swipe
        // then deleted over and over and froze the app).
        guard !deleting else { return }
        deleting = true
        offset = 0
        settled = 0
        DispatchQueue.main.async { onDelete() }
    }
}

/// A pan for SwipeToDeleteRow that begins only when the drag starts out sideways, leaving vertical drags to the
/// scroll view. It runs alongside the scroll view's own pan, so the row follows the finger from the first point.
@available(iOS 26.0, *)
private struct SidewaysPan: UIGestureRecognizerRepresentable {
    let enabled: Bool
    /// The sideways distance moved so far.
    let changed: (CGFloat) -> Void
    /// The distance moved and the speed at the end.
    let ended: (CGFloat, CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        return Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        pan.isEnabled = enabled
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = enabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let dx = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .began, .changed: changed(dx)
        case .ended, .cancelled, .failed: ended(dx, recognizer.velocity(in: recognizer.view).x)
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}
#endif
