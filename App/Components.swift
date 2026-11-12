import CoreHaptics
import SwiftUI
import UIKit

// MARK: - Haptics

/// The app's haptics: each kind of action has its own feel, so the hand learns them. Generators are created once
/// and kept ready, so taps feel instant (and the system's Haptics switch turns them all off).
enum Feedback {
    private static let selection = UISelectionFeedbackGenerator()
    private static let impact = UIImpactFeedbackGenerator(style: .rigid)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notification = UINotificationFeedbackGenerator()

    static func prepare() {
        selection.prepare()
        impact.prepare()
        soft.prepare()
        medium.prepare()
        rigid.prepare()
        notification.prepare()
    }

    /// A value moved a step: a switch flipped, a slider passed a mark. The lightest click.
    static func tick() {
        selection.selectionChanged()
        selection.prepare()
    }

    /// Opening a screen or pressing an ordinary button: a soft, cushioned tap.
    static func tap() {
        soft.impactOccurred(intensity: 0.7)
        soft.prepare()
    }

    /// Choosing something (a theme, a colour, a preset): a fuller, rounder knock.
    static func choose() {
        medium.impactOccurred(intensity: 0.75)
        medium.prepare()
    }

    /// Something added (a language, a shortcut): the system's two-beat success.
    static func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    /// Something removed or forgotten: short and sharp.
    static func delete() {
        rigid.impactOccurred(intensity: 1)
        rigid.prepare()
    }

    /// A swipe passing the point where letting go deletes: a lighter sharp click, before the real one.
    static func threshold() {
        rigid.impactOccurred(intensity: 0.5)
        rigid.prepare()
    }

    /// Every setting put back: the system's warning buzz.
    static func warning() {
        notification.notificationOccurred(.warning)
        notification.prepare()
    }

    /// The haptic engine, for the long buzz (nil on hardware without one).
    private static let engine: CHHapticEngine? = {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        let engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        return engine
    }()

    /// Something dangerous is about to happen (Reset all settings): half a second of strong, continuous buzz.
    static func danger() {
        if let engine = engine {
            do {
                try engine.start()
                let buzz = CHHapticEvent(eventType: .hapticContinuous,
                                         parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                                                      CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.75)],
                                         relativeTime: 0,
                                         duration: 0.5)
                try engine.makePlayer(with: CHHapticPattern(events: [buzz], parameters: [])).start(atTime: CHHapticTimeImmediate)
                return
            } catch {
                // Fall through to the taps below.
            }
        }
        // Without the engine: ten strong taps over the same half second.
        for step in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.05) {
                rigid.impactOccurred(intensity: 1)
            }
        }
    }

    /// Plays the keyboard's key-press vibration at the given strength (0...1), with the feel's sharpness
    /// (0 = soft ... 1 = rigid; the stored one when nil).
    static func test(strength: Double, sharpness: Double? = nil) {
        guard strength > 0.01 else { return }
        let style = self.style(forSharpness: sharpness ?? Settings.shared.hapticSharpness)
        let generator = style == .rigid ? impact : UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred(intensity: CGFloat(strength))
        impact.prepare()
    }

    /// Mirrors Haptics.style(forSharpness:) in the keyboard.
    static func style(forSharpness sharpness: Double) -> UIImpactFeedbackGenerator.FeedbackStyle {
        switch sharpness {
        case ..<0.2: return .soft
        case ..<0.4: return .light
        case ..<0.6: return .medium
        case ..<0.8: return .heavy
        default: return .rigid
        }
    }
}

extension Notification.Name {
    /// Posted after "Reset all settings" so sliders can reload their local values.
    static let hunKeysSettingsReset = Notification.Name("hunkeys.settingsReset")
}

// MARK: - Colours

extension Color {
    init(_ rgba: ThemeRGBA) {
        self.init(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
    }

    init(accent choice: AccentChoice) {
        self.init(.sRGB, red: choice.rgb.red, green: choice.rgb.green, blue: choice.rgb.blue, opacity: 1)
    }

    /// "#RRGGBB" -> Color (falls back to `fallback` when the text isn't a valid hex colour).
    init(hex: String, fallback: Color = .gray) {
        if let rgb = HexColor.parse(hex) {
            self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
        } else {
            self = fallback
        }
    }

    /// "#RRGGBB" for this colour (alpha is dropped).
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return HexColor.string(red: Double(r), green: Double(g), blue: Double(b))
    }

    /// The accent colour currently chosen in the app (custom hex if set, else the preset).
    static func currentAccent(name: String, hex: String) -> Color {
        if let rgb = HexColor.parse(hex) {
            return Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
        }
        return Color(accent: AccentChoice(rawValue: name) ?? .blue)
    }
}

// MARK: - Controls
// Each control owns its own @AppStorage, so changing one setting only redraws that one row.

struct SettingToggle: View {
    private let title: String
    private let subtitle: String?
    private let symbol: String?
    private let color: Color
    private let feature: LanguageFeature?
    @AppStorage private var isOn: Bool
    @ObservedObject private var languages = EnabledLanguages.shared
    @Environment(\.isEnabled) private var isEnabled

    /// `symbol`: an icon tile in front of the title (as on the main screen). `feature`: one some languages can't
    /// use (greyed out when none of the enabled languages can, with a note naming the ones that can't).
    init(_ title: String, key: String, defaultValue: Bool, subtitle: String? = nil,
         symbol: String? = nil, color: Color = .accentColor, feature: LanguageFeature? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.color = color
        self.feature = feature
        _isOn = AppStorage(wrappedValue: defaultValue, key, store: SharedStore.defaults)
    }

    private var unavailable: Bool { return feature.map { languages.lacking($0).all } ?? false }

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                if let symbol = symbol { IconTile(symbol: symbol, color: color) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let subtitle = subtitle {
                        Text(subtitle).font(.footnote).foregroundColor(.secondary)
                    }
                    if let feature = feature { FeatureNote(feature) }
                }
            }
        }
        .onChange(of: isOn) { _ in Feedback.tick() }
        .disabled(unavailable)
        .opacity(unavailable || !isEnabled ? 0.45 : 1)
    }
}

/// The app's icon: a small keycap in a colour of its own with the symbol on it in white. The cap has a top and a
/// darker skirt under it, as a key seen from the front.
struct IconTile: View {
    let symbol: String
    var color: Color = .accentColor

    var body: some View {
        Keycap(color: color) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
        }
        .accessibilityHidden(true)
    }
}

/// A keycap with a short text on it (a language's code, a key's letter).
struct KeycapLabel: View {
    let text: String
    var color: Color = .accentColor
    var size: CGFloat = 32

    var body: some View {
        Keycap(color: color, size: size) {
            Text(text)
                .font(.system(size: text.count > 2 ? size * 0.34 : size * 0.44, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 2)
        }
    }
}

/// The keycap itself: the skirt, the top of the key a little above it, and the legend on the top.
struct Keycap<Legend: View>: View {
    var color: Color = .accentColor
    var size: CGFloat = 32
    @ViewBuilder let legend: () -> Legend
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
        let lip: CGFloat = max(2, size * 0.09)
        // In full colour: the skirt is the colour darkened, the top the colour itself with a little light on its
        // upper half, and the legend white.
        ZStack {
            shape.fill(color)
            shape.fill(Color.black.opacity(scheme == .dark ? 0.38 : 0.26))
            shape.fill(color).padding(.bottom, lip)
            shape.fill(LinearGradient(colors: [Color.white.opacity(0.24), Color.white.opacity(0)],
                                      startPoint: .top, endPoint: .bottom))
                .padding(.bottom, lip)
            legend()
                .foregroundColor(.white)
                .frame(width: size, height: size - lip)
                .padding(.bottom, lip)
        }
        .frame(width: size, height: size)
    }
}

/// A row that opens a screen or shows a value: its keycap, its title (and a line under it), and what it is set to.
struct SettingsRow: View {
    let title: String
    let symbol: String
    var color: Color = .accentColor
    var value: String? = nil
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let value = value {
                Text(value)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

/// A slider that keeps its value locally while dragging and saves when the finger lifts
/// (writing shared defaults on every tick made the whole screen stutter).
struct SettingSlider: View {
    private let title: String
    private let range: ClosedRange<Double>
    private let step: Double
    private let format: (Double) -> String
    private let showsTest: Bool
    private let subtitle: String?
    private let key: String
    private let defaultValue: Double

    @AppStorage private var stored: Double
    @State private var local: Double
    @State private var editing = false

    init(_ title: String,
         key: String,
         defaultValue: Double,
         range: ClosedRange<Double>,
         step: Double,
         showsTest: Bool = false,
         subtitle: String? = nil,
         format: @escaping (Double) -> String) {
        self.title = title
        self.subtitle = subtitle
        self.key = key
        self.defaultValue = defaultValue
        self.range = range
        self.step = step
        self.showsTest = showsTest
        self.format = format
        _stored = AppStorage(wrappedValue: defaultValue, key, store: SharedStore.defaults)
        let current = SharedStore.defaults.object(forKey: key) as? Double ?? defaultValue
        _local = State(initialValue: min(max(current, range.lowerBound), range.upperBound))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if subtitle != nil || showsTest {
                HStack {
                    if let subtitle = subtitle {
                        Text(subtitle).font(.footnote).foregroundColor(.secondary)
                    }
                    Spacer()
                    if showsTest {
                        Button(tr("Test")) { Feedback.test(strength: local) }
                            .buttonStyle(ActionButtonStyle(compact: true))
                    }
                }
            }
            ValueBar(title: title, value: $local, range: range, step: step, format: format) { isEditing in
                editing = isEditing
                if !isEditing { stored = local }
            }
        }
        .padding(.vertical, 2)
        // The system slider can report the drag's end before its last step: a value that arrives after it is saved too.
        .onChange(of: local) { value in
            if !editing && value != stored { stored = value }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hunKeysSettingsReset)) { _ in
            local = min(max(defaultValue, range.lowerBound), range.upperBound)
        }
    }
}

// MARK: - Styling helpers

/// Slight shrink while pressed, so every card and swatch answers the finger at once.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(GlassSheen(pressed: configuration.isPressed).allowsHitTesting(false))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

/// Every plain button and row of the glass lists: while held, the row darkens a little inside its card and leans
/// in, as a row of the system's own glass lists does. (A second piece of glass under the finger, inside a card
/// that is glass already, is not how the system's material is used.)
struct GlassPressStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled
        return configuration.label
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(pressed ? 0.09 : 0))
                    .padding(.horizontal, -10)
                    .padding(.vertical, -6)
                    .allowsHitTesting(false))
            .scaleEffect(pressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.easeOut(duration: pressed ? 0.08 : 0.25), value: pressed)
    }
}

/// The light a press puts on a frosted button before iOS 26. Real Liquid Glass answers the finger itself (its
/// `interactive` form), so nothing is painted over it there.
struct GlassSheen: View {
    let pressed: Bool
    var shape: AnyInsettableShape = AnyInsettableShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    @Environment(\.colorScheme) private var scheme

    init(pressed: Bool) {
        self.pressed = pressed
    }

    init<S: InsettableShape>(pressed: Bool, shape: S) {
        self.pressed = pressed
        self.shape = AnyInsettableShape(shape)
    }

    @ViewBuilder var body: some View {
        if #available(iOS 26.0, *) {
            EmptyView()
        } else if pressed {
            shape
                .fill(Color.white.opacity(scheme == .dark ? 0.14 : 0.3))
                .transition(.opacity)
        }
    }
}

/// Any insettable shape, so GlassSheen can take the shape of whatever it lights.
struct AnyInsettableShape: InsettableShape {
    private let base: (CGRect) -> Path
    private let insetBy: (CGFloat) -> AnyInsettableShape

    init<S: InsettableShape>(_ shape: S) {
        base = { shape.path(in: $0) }
        insetBy = { AnyInsettableShape(shape.inset(by: $0)) }
    }

    func path(in rect: CGRect) -> Path { return base(rect) }
    func inset(by amount: CGFloat) -> AnyInsettableShape { return insetBy(amount) }
}

/// The app's action button: a full-width accent-tinted glass capsule (or small, for a button beside a title), red
/// when destructive, with white text.
struct ActionButtonStyle: ButtonStyle {
    var compact = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        let destructive = configuration.role == .destructive
        let color: Color = destructive ? .red : .accentColor
        let small = compact || controlSize == .small
        return configuration.label
            .font((small ? Font.footnote : Font.body).weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: small ? nil : .infinity)
            .padding(.horizontal, small ? 14 : 16)
            .padding(.vertical, small ? 6 : 11)
            .glassShape(Capsule(), tint: color.opacity(configuration.isPressed ? 0.95 : 0.8), interactive: true)
            .overlay(GlassSheen(pressed: configuration.isPressed, shape: Capsule()).allowsHitTesting(false))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A section's title, in sentence case: its glyph in the section's colour (the accent unless one is given) and
/// its name.
struct SectionHeader: View {
    let title: String
    let symbol: String
    let color: Color

    init(_ title: String, symbol: String, color: Color = .accentColor) {
        self.title = title
        self.symbol = symbol
        self.color = color
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary.opacity(0.75))
        }
        .textCase(nil)
    }
}

/// Small rounded status pill.
struct StatusChip: View {
    let text: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.caption.weight(.bold))
            Text(text).font(.caption.weight(.semibold)).lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(color.opacity(0.14)))
        .accessibilityElement(children: .combine)
    }
}

/// Applies the chosen accent colour as the tint of everything inside.
struct AccentTint: ViewModifier {
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex

    func body(content: Content) -> some View {
        content
            .tint(Color.currentAccent(name: accentName, hex: accentHex))
            // A new accent fades in over the old one, wherever it is drawn.
            .animation(AccentTint.fade, value: accentName + accentHex)
    }

    /// How a new accent takes over from the old one (the backdrop's fade, and everything else's).
    static let fade = Animation.easeInOut(duration: 0.7)
}

// MARK: - Accent colour

/// The preset swatches, and last the system colour picker for any colour (it takes the place of grey, which a
/// custom colour covers).
struct AccentPicker: View {
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex

    private let columns = Array(repeating: GridItem(.flexible(minimum: 30), spacing: 8), count: 6)
    private let presets = AccentChoice.allCases.filter { $0 != .graphite }
    /// A colour picked in the colour picker, held until the picker closes (then the backdrop fades over to it).
    @State private var pendingHex: String?
    @State private var watching = false

    private var isCustom: Bool { return HexColor.parse(accentHex) != nil }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(presets, id: \.rawValue) { choice in
                let selected = !isCustom && accentName == choice.rawValue
                Button {
                    guard isCustom || accentName != choice.rawValue else { return }
                    Feedback.choose()
                    withAnimation(AccentTint.fade) {
                        accentName = choice.rawValue
                        accentHex = ""
                    }
                } label: {
                    Circle()
                        .fill(Color(accent: choice))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .opacity(selected ? 1 : 0))
                        .overlay(Circle().stroke(Color.primary.opacity(selected ? 0.9 : 0), lineWidth: 2).padding(-4))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(tr(choice.displayName))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            customSwatch
        }
        .padding(.vertical, 4)
    }

    /// The system colour well: choosing a colour sets the custom accent (a grey chosen before still shows as it).
    private var customSwatch: some View {
        let selected = isCustom || accentName == AccentChoice.graphite.rawValue
        return ColorPicker(tr("Custom colour"), selection: Binding(
            get: { pendingHex.map { Color(hex: $0) } ?? Color.currentAccent(name: accentName, hex: accentHex) },
            set: { newColor in
                // Held while the picker is open; the accent changes once it has closed.
                pendingHex = newColor.hexString
                watchPicker()
            }), supportsOpacity: false)
            .labelsHidden()
            .scaleEffect(1.2)
            .overlay(Circle().stroke(Color.primary.opacity(selected ? 0.9 : 0), lineWidth: 2).frame(width: 42, height: 42))
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Whether the system is showing something over the app (the colour picker, while it is open).
    private static var isPresenting: Bool {
        func presenting(_ controller: UIViewController) -> Bool {
            return controller.presentedViewController != nil || controller.children.contains(where: presenting)
        }
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
        guard let root = (windows.first(where: { $0.isKeyWindow }) ?? windows.first)?.rootViewController else { return false }
        return presenting(root)
    }

    /// Waits for the colour picker to close, then, if the colour is not the one the accent already is, sets it. A
    /// colour left as it was changes nothing.
    private func watchPicker() {
        guard !watching else { return }
        watching = true
        Task { @MainActor in
            // The picker is open while something is shown over the app.
            while AccentPicker.isPresenting { try? await Task.sleep(nanoseconds: 150_000_000) }
            // Its dismissal finishes first.
            try? await Task.sleep(nanoseconds: 350_000_000)
            watching = false
            guard let hex = pendingHex else { return }
            pendingHex = nil
            guard hex != accentHex else { return }
            withAnimation(AccentTint.fade) { accentHex = hex }
        }
    }
}

// MARK: - Features some languages can't use

/// The enabled languages, kept current while the app runs (the Languages screen changes them), so the settings a
/// language can't use follow at once.
final class EnabledLanguages: ObservableObject {
    static let shared = EnabledLanguages()

    @Published private(set) var list: [Language]
    private var observer: NSObjectProtocol?

    private init() {
        list = EnabledLanguages.read()
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                                          object: SharedStore.defaults, queue: .main) { [weak self] _ in
            let current = EnabledLanguages.read()
            if current != self?.list { self?.list = current }
        }
    }

    /// Straight from the shared defaults (the Settings snapshot can lag a moment behind a change).
    private static func read() -> [Language] {
        let codes = SharedStore.defaults.stringArray(forKey: SettingKey.enabledLanguages) ?? SettingDefault.enabledLanguages
        return Language.list(from: codes)
    }

    /// The enabled languages that can't use `feature`, and whether that is all of them.
    func lacking(_ feature: LanguageFeature) -> (languages: [Language], all: Bool) {
        return Language.lacking(feature, among: list)
    }
}

/// Names the enabled languages that can't use a setting: "Off while typing in 한국어 and ไทย." when the others can
/// (the keyboard leaves it out only in those), "Not available in 日本語." when none can (the setting is greyed out).
struct FeatureNote: View {
    let feature: LanguageFeature
    @ObservedObject private var languages = EnabledLanguages.shared

    init(_ feature: LanguageFeature) {
        self.feature = feature
    }

    private var text: String? {
        let lacking = languages.lacking(feature)
        guard !lacking.languages.isEmpty else { return nil }
        let formatter = ListFormatter()
        formatter.locale = AppLanguage.locale
        let names = formatter.string(from: lacking.languages.map { $0.localizedName }) ?? ""
        return lacking.all ? tr("Not available in %@.", "\(names)") : tr("Off while typing in %@.", "\(names)")
    }

    var body: some View {
        if let text = text {
            Label(text, systemImage: "globe")
                .font(.footnote)
                .foregroundColor(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
