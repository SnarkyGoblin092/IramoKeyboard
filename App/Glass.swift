import SwiftUI

// MARK: - Liquid Glass look
//
// Every screen sits on a soft, accent-tinted backdrop, and its rows and cards are glass on top of it: real Liquid
// Glass (`glassEffect`) on iOS 26 and later, a frosted material before that.

/// The light behind the glass: the grouped background with a few large, blurred washes of colour.
struct GlassBackdrop: View {
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let accent = Color.currentAccent(name: accentName, hex: accentHex)
        let strength = scheme == .dark ? 0.45 : 0.30
        return ZStack {
            Color(.systemGroupedBackground)
            Circle()
                .fill(accent.opacity(strength))
                .frame(width: 460, height: 460)
                .blur(radius: 110)
                .offset(x: -150, y: -300)
            Circle()
                .fill(Color.purple.opacity(strength * 0.6))
                .frame(width: 400, height: 400)
                .blur(radius: 120)
                .offset(x: 170, y: 80)
            Circle()
                .fill(Color.teal.opacity(strength * 0.5))
                .frame(width: 420, height: 420)
                .blur(radius: 130)
                .offset(x: -110, y: 460)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
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

extension View {
    /// A screen of the app: its list or scroll view on the glass backdrop.
    func glassScreen() -> some View {
        return self
            .scrollContentBackground(.hidden)
            .background(GlassBackdrop())
    }

    /// The rows of a list section, drawn as glass.
    func glassRows() -> some View {
        return self.listRowBackground(GlassRowFill())
    }

    /// A rounded card of Liquid Glass (a frosted material before iOS 26).
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 24, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(tint.map { Glass.regular.tint($0.opacity(0.35)) } ?? .regular, in: shape)
        } else {
            self.background(shape.fill(.thinMaterial)).background(shape.fill(tint?.opacity(0.18) ?? .clear))
        }
        #else
        self.background(shape.fill(.thinMaterial)).background(shape.fill(tint?.opacity(0.18) ?? .clear))
        #endif
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

    /// The finger is on the slider (a preset changing the value must not click).
    @State private var editing = false

    // Spelled out: the private state would make the memberwise initializer private.
    init(title: String, symbol: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double,
         format: @escaping (Double) -> String) {
        self.title = title
        self.symbol = symbol
        _value = value
        self.range = range
        self.step = step
        self.format = format
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                Text(format(value))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range, step: step) { editing = $0 }
                .accessibilityLabel(title)
                .accessibilityValue(format(value))
                .onChange(of: value) { _ in if editing { Feedback.tick() } }
        }
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
    @ObservedObject private var languages = EnabledLanguages.shared

    init(title: String, subtitle: String, isOn: Binding<Bool>, feature: LanguageFeature? = nil) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.feature = feature
    }

    private var unavailable: Bool { return feature.map { languages.lacking($0).all } ?? false }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(subtitle).font(.footnote).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let feature = feature { FeatureNote(feature) }
            }
        }
        .onChange(of: isOn) { _ in Feedback.tick() }
        .disabled(unavailable)
        .opacity(unavailable ? 0.45 : 1)
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
            Picker(title ?? "Preset", selection: Binding(get: { selected ?? -1 }, set: { index in
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
