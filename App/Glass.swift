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

/// A list row's background: frosted glass over the backdrop.
struct GlassRowFill: View {
    var body: some View {
        Rectangle().fill(.thinMaterial)
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

/// A row of tabs drawn as glass buttons; the chosen one is filled with the accent colour.
struct GlassTabs<Tab: Hashable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    let title: (Tab) -> String
    let symbol: (Tab) -> String
    /// A small dot after the title (e.g. the feature is switched on).
    var marked: (Tab) -> Bool = { _ in false }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(tabs, id: \.self) { tab in
                let isSelected = tab == selection
                Button {
                    guard tab != selection else { return }
                    Feedback.tick()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selection = tab }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: symbol(tab)).font(.system(size: 18, weight: .medium))
                        HStack(spacing: 4) {
                            Text(title(tab)).font(.footnote.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                            if marked(tab) {
                                Circle().frame(width: 5, height: 5).accessibilityHidden(true)
                            }
                        }
                    }
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background {
                        // `.tint` is the accent the app applies (AccentTint), unlike Color.accentColor.
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.primary.opacity(0.06)))
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

/// A slider bound straight to a stored value: it follows the value when something else changes it (a preset),
/// and only saves when the finger lifts.
struct GlassSlider: View {
    let title: String
    let symbol: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    @State private var dragging: Double?

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
                Text(format(dragging ?? value))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(value: Binding(get: { dragging ?? value }, set: { dragging = $0 }), in: range, step: step) { editing in
                if !editing, let final = dragging {
                    value = final
                    dragging = nil
                }
            }
            .accessibilityLabel(title)
            .accessibilityValue(format(dragging ?? value))
            .onChange(of: dragging) { new in if new != nil { Feedback.tick() } }
        }
    }
}

/// An option toggle with a title and a line of explanation, for the glass cards.
struct GlassToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.semibold))
                Text(subtitle).font(.footnote).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: isOn) { _ in Feedback.tick() }
    }
}

/// A preset choice drawn as a small card with a picture; the chosen one has an accent outline.
struct PresetCard<Picture: View>: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let picture: () -> Picture

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                picture()
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.07)))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? AnyShapeStyle(TintShapeStyle().opacity(0.14)) : AnyShapeStyle(Color.primary.opacity(0.04))))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.clear), lineWidth: 2))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
