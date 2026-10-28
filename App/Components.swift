import SwiftUI
import UIKit

// MARK: - Haptics

/// Generators are created once and kept ready, so taps feel instant.
enum Feedback {
    private static let selection = UISelectionFeedbackGenerator()
    private static let impact = UIImpactFeedbackGenerator(style: .rigid)

    static func prepare() {
        selection.prepare()
        impact.prepare()
    }

    static func tick() {
        selection.selectionChanged()
        selection.prepare()
    }

    /// Plays the keyboard's key-press vibration at the given strength (0...1).
    static func test(strength: Double) {
        guard strength > 0.01 else { return }
        impact.impactOccurred(intensity: CGFloat(strength))
        impact.prepare()
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
}

// MARK: - Controls
// Each control owns its own @AppStorage, so changing one setting only redraws that one row.

struct SettingToggle: View {
    private let title: String
    private let subtitle: String?
    @AppStorage private var isOn: Bool

    init(_ title: String, key: String, defaultValue: Bool, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        _isOn = AppStorage(wrappedValue: defaultValue, key, store: SharedStore.defaults)
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle = subtitle {
                    Text(subtitle).font(.footnote).foregroundColor(.secondary)
                }
            }
        }
        .onChange(of: isOn) { _ in Feedback.tick() }
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
         format: @escaping (Double) -> String) {
        self.title = title
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
            Slider(value: $local, in: range, step: step) { editing in
                if !editing { stored = local }
            }
            .onChange(of: local) { _ in Feedback.tick() }
        }
        .padding(.vertical, 2)
        .onReceive(NotificationCenter.default.publisher(for: .hunKeysSettingsReset)) { _ in
            local = min(max(defaultValue, range.lowerBound), range.upperBound)
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}


/// Key-roundness slider with a live preview of a few sample keys.
struct RoundnessSlider: View {
    @AppStorage(SettingKey.keyRoundness, store: SharedStore.defaults) private var stored = SettingDefault.keyRoundness
    @State private var local: Double

    init() {
        let current = SharedStore.defaults.object(forKey: SettingKey.keyRoundness) as? Double ?? SettingDefault.keyRoundness
        _local = State(initialValue: min(max(current, 0), 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Key roundness")
                Spacer()
                Text("\(Int((local * 100).rounded()))%")
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            HStack(spacing: 6) {
                ForEach(["Q", "A", "Z", "\u{23CE}"], id: \.self) { label in
                    RoundedRectangle(cornerRadius: local * 22, style: .continuous)
                        .fill(Color(.systemGray4))
                        .frame(height: 44)
                        .overlay(Text(label).font(.system(size: 20)).foregroundColor(.primary))
                }
            }
            Slider(value: $local, in: 0...1, step: 0.02) { editing in
                if !editing { stored = local }
            }
            .onChange(of: local) { _ in Feedback.tick() }
        }
        .padding(.vertical, 2)
        .onReceive(NotificationCenter.default.publisher(for: .hunKeysSettingsReset)) { _ in
            local = SettingDefault.keyRoundness
        }
    }
}
