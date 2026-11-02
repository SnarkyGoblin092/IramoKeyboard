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
        // An aurora built from the accent itself: the same colour turned a little each way round the colour wheel,
        // so the whole app takes its character from the accent chosen.
        return ZStack {
            Color(.systemGroupedBackground)
            Circle()
                .fill(accent.opacity(strength))
                .frame(width: 460, height: 460)
                .blur(radius: 110)
                .offset(x: -150, y: -300)
            Circle()
                .fill(accent.hueShifted(by: 0.09).opacity(strength * 0.65))
                .frame(width: 400, height: 400)
                .blur(radius: 120)
                .offset(x: 170, y: 80)
            Circle()
                .fill(accent.hueShifted(by: -0.10).opacity(strength * 0.55))
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

/// The app's signature edge: a hairline that catches the light at the top left and fades out towards the bottom
/// right, on every glass card.
private struct GlassEdge<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let light = scheme == .dark ? 0.32 : 0.85
        content.overlay(
            shape.strokeBorder(
                LinearGradient(colors: [Color.white.opacity(light), Color.white.opacity(0.05), .accentColor.opacity(0.25)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.8)
                .allowsHitTesting(false))
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

    func glassEdge<S: InsettableShape>(_ shape: S) -> some View {
        return modifier(GlassEdge(shape: shape))
    }

    /// The app's typeface: the system's rounded design where the system has it (iOS 16.1 and later).
    @ViewBuilder
    func roundedType() -> some View {
        if #available(iOS 16.1, *) { self.fontDesign(.rounded) } else { self }
    }

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
            self.glassEffect(tint.map { Glass.regular.tint($0.opacity(0.35)) } ?? .regular, in: shape).glassEdge(shape)
        } else {
            self.background(shape.fill(.thinMaterial)).background(shape.fill(tint?.opacity(0.18) ?? .clear)).glassEdge(shape)
        }
        #else
        self.background(shape.fill(.thinMaterial)).background(shape.fill(tint?.opacity(0.18) ?? .clear)).glassEdge(shape)
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

    var body: some View {
        ValueBar(title: title, symbol: symbol, value: $value, range: range, step: step, format: format)
    }
}

/// The app's slider: a capsule that fills with the accent up to the value, its name and value written on it.
/// Drawn by hand rather than the system Slider, whose own haptics (a hard knock at either end) came on top of the
/// app's light click per step. Drag sideways anywhere on it; vertical drags still scroll the screen.
struct ValueBar: View {
    let title: String
    var symbol: String? = nil
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String
    /// Called with true when a drag starts and false when it ends.
    var onEditingChanged: (Bool) -> Void = { _ in }

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
        GeometryReader { geometry in
            let width = geometry.size.width
            let fraction = CGFloat(min(max((value - range.lowerBound) / span, 0), 1))
            let thumb: CGFloat = 30
            let travel = max(0, width - thumb)
            let edge = thumb / 2 + travel * fraction
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let symbol = symbol {
                        Image(systemName: symbol).foregroundStyle(.tint)
                    }
                    Text(title).font(.subheadline).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Text(format(value))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .glassShape(Capsule(), tint: Color.accentColor.opacity(0.25))
                }
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
                        Feedback.tick()   // once per step; nothing more at either end
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

    /// About how wide a letter key is in portrait (ten keys across, less the gap between them).
    static func letterKeyWidth(keyGap: Double) -> Double {
        return portraitWidth / 10 - keyGap
    }

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
                        Toggle("", isOn: $isOn).labelsHidden().allowsHitTesting(false)
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

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Group(sections: content) { sections in
                        ForEach(sections) { section in
                            GlassCardSection(section: section)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .environment(\.inGlassCards, true)
        } else {
            list
        }
        #else
        list
        #endif
    }

    private var list: some View {
        List { content }
            .listStyle(.insetGrouped)
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
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.bottom, 7)
            }
            VStack(spacing: 12) {
                ForEach(runs.indices, id: \.self) { index in
                    let run = runs[index]
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
                .padding(.horizontal, 16)
                .padding(.top, 7)
            }
        }
        .padding(.top, section.header.isEmpty ? 20 : 24)
    }

    private func card(_ rows: [Subview]) -> some View {
        let shape = RoundedRectangle(cornerRadius: GlassMetrics.cardRadius, style: .continuous)
        return VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                if row.containerValues.glassBareRow {
                    row
                } else {
                    row.glassRowPadding()
                }
                if index < rows.count - 1 {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .clipShape(shape)   // a row's Delete button keeps the card's corners
        .glassEffect(.regular, in: shape)
        .glassEdge(shape)
    }

    private struct Run {
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
                runs.append(Run(outside: outside, rows: [row]))
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

/// The app's switch: a glass groove that fills with the accent when on, and a glass bead that slides across it
/// (a frosted material before iOS 26). Every Toggle in the app takes it (ContentView sets it on the whole app).
struct GlassSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
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

private struct SwitchTrait: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.accessibilityAddTraits(.isToggle)
        } else {
            content.accessibilityAddTraits(.isButton)
        }
    }
}

/// The switch itself: the groove and the bead.
private struct GlassSwitchKnob: View {
    let isOn: Bool
    @Environment(\.isEnabled) private var isEnabled
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex

    var body: some View {
        let accent = Color.currentAccent(name: accentName, hex: accentHex)
        let bead: CGFloat = 27
        ZStack(alignment: .leading) {
            Capsule().fill(Color.clear).frame(width: 52, height: 32)
                .glassShape(Capsule(), tint: isOn ? accent.opacity(0.85) : nil)
            Circle().fill(Color.clear).frame(width: bead, height: bead)
                .glassShape(Circle(), tint: Color.white.opacity(0.4), interactive: true)
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1.5)
                .offset(x: isOn ? 52 - bead - 2.5 : 2.5)
        }
        .frame(width: 52, height: 32)
        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: isOn)
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

/// A row that slides left to show a red Delete button inside the row itself; a long swipe deletes at once.
private struct SwipeToDeleteRow<Content: View>: View {
    let canDelete: Bool
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var settled: CGFloat = 0
    /// Whether the current drag is a sideways swipe (decided once, at its start); nil until it is known.
    @State private var horizontal: Bool?
    private let buttonWidth: CGFloat = 84
    /// How far the Delete button may grow: a long swipe that reaches it deletes at once.
    private let maxReveal: CGFloat = 200
    private let settle = Animation.spring(response: 0.35, dampingFraction: 0.86)

    var body: some View {
        // The row stays put (the name never slides off screen); the Delete button grows in from the right edge.
        content()
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
            // Alongside the scroll view's own pan, so the row follows the finger from the first point instead
            // of waiting for the scroll view to give up (the stall partway into a slow swipe).
            .simultaneousGesture(drag, including: canDelete ? .all : .subviews)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                let dx = value.translation.width, dy = value.translation.height
                if horizontal == nil { horizontal = abs(dx) > abs(dy) }
                guard horizontal == true else { return }
                let target = min(0, settled + dx)
                // Past the full-delete point the button resists instead of stopping dead.
                let resisted = target < -maxReveal ? -maxReveal + (target + maxReveal) * 0.25 : target
                if (offset > -maxReveal) != (resisted > -maxReveal) { Feedback.threshold() }   // crossing it
                offset = resisted
            }
            .onEnded { value in
                defer { horizontal = nil }
                guard horizontal == true else { return }
                let end = min(0, settled + value.translation.width)
                if end <= -maxReveal {
                    delete()
                    return
                }
                // A quick flick counts as far as it was heading.
                let heading = min(0, settled + value.predictedEndTranslation.width)
                let open = min(end, heading) < -buttonWidth / 2
                withAnimation(settle) { offset = open ? -buttonWidth : 0 }
                settled = open ? -buttonWidth : 0
            }
    }

    private func close() {
        guard offset != 0 else { return }
        withAnimation(settle) { offset = 0 }
        settled = 0
    }

    private func delete() {
        offset = 0
        settled = 0
        onDelete()
    }
}
