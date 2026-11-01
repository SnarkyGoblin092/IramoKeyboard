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
    @AppStorage private var isOn: Bool

    /// `symbol`: an icon tile in front of the title (as on the main screen).
    init(_ title: String, key: String, defaultValue: Bool, subtitle: String? = nil,
         symbol: String? = nil, color: Color = .gray) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.color = color
        _isOn = AppStorage(wrappedValue: defaultValue, key, store: SharedStore.defaults)
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                if let symbol = symbol { IconTile(symbol: symbol, color: color) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let subtitle = subtitle {
                        Text(subtitle).font(.footnote).foregroundColor(.secondary)
                    }
                }
            }
        }
        .onChange(of: isOn) { _ in Feedback.tick() }
    }
}

/// A white symbol on a small rounded square of colour, like the icons of the system Settings app.
struct IconTile: View {
    let symbol: String
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(LinearGradient(colors: [color.opacity(0.85), color], startPoint: .top, endPoint: .bottom))
            .frame(width: 29, height: 29)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white))
            .accessibilityHidden(true)
    }
}

/// A row of the main screen: icon tile, title and (dimmed, on the right) what it is set to.
struct SettingsRow: View {
    let title: String
    let symbol: String
    let color: Color
    var value: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, color: color)
            Text(title)
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
            HStack {
                Text(title)
                Spacer()
                Text(format(local))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                if showsTest {
                    Button("Test") { Feedback.test(strength: local) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            if let subtitle = subtitle {
                Text(subtitle).font(.footnote).foregroundColor(.secondary)
            }
            Slider(value: $local, in: range, step: step) { editing in
                if !editing { stored = local }
            }
            .accessibilityLabel(title)
            .accessibilityValue(format(local))
            .onChange(of: local) { _ in Feedback.tick() }
        }
        .padding(.vertical, 2)
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
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A section's title: quiet text, as in the system Settings app (the rows carry the colour). `symbol` and
/// `color` tint a small glyph in front of it.
struct SectionHeader: View {
    let title: String
    let symbol: String
    let color: Color

    init(_ title: String, symbol: String, color: Color) {
        self.title = title
        self.symbol = symbol
        self.color = color
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
                .accessibilityHidden(true)
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .textCase(.uppercase)
        .padding(.leading, -4)
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

extension View {
    /// A soft tap when the view is touched, alongside what it does (rows that open a screen).
    func hapticTap() -> some View {
        return self.simultaneousGesture(TapGesture().onEnded { Feedback.tap() })
    }
}

/// Applies the chosen accent colour as the tint of everything inside.
struct AccentTint: ViewModifier {
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex

    func body(content: Content) -> some View {
        content.tint(Color.currentAccent(name: accentName, hex: accentHex))
    }
}

// MARK: - Accent colour

/// The preset swatches. Custom colours are chosen in `AccentCustomRow` right below.
struct AccentPicker: View {
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex

    private let columns = Array(repeating: GridItem(.flexible(minimum: 30), spacing: 8), count: 6)

    private var isCustom: Bool { return HexColor.parse(accentHex) != nil }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(AccentChoice.allCases, id: \.rawValue) { choice in
                let selected = !isCustom && accentName == choice.rawValue
                Button {
                    guard isCustom || accentName != choice.rawValue else { return }
                    Feedback.choose()
                    accentName = choice.rawValue
                    accentHex = ""
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
                .accessibilityLabel(choice.displayName)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

/// A normal, visible row with the system colour picker. Choosing a colour sets the custom accent.
struct AccentCustomRow: View {
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex

    private var isCustom: Bool { return HexColor.parse(accentHex) != nil }

    var body: some View {
        ColorPicker(selection: Binding(
            get: { Color.currentAccent(name: accentName, hex: accentHex) },
            set: { newColor in
                let hex = newColor.hexString
                guard hex != accentHex else { return }
                accentHex = hex
            }), supportsOpacity: false) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Custom colour")
                Text(isCustom ? accentHex.uppercased() : "Pick any colour")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}
