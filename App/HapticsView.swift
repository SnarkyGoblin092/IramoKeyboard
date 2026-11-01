import SwiftUI

/// Key-press vibration (its strength and how sharp it feels), the cursor's ticks and key clicks. The keyboard
/// maps the sharpness onto the system's impact styles (Haptics.style(forSharpness:)).
struct HapticsView: View {
    @AppStorage(SettingKey.vibration, store: SharedStore.defaults) private var strength = SettingDefault.vibration
    @AppStorage(SettingKey.hapticSharpness, store: SharedStore.defaults) private var sharpness = SettingDefault.hapticSharpness
    @AppStorage(SettingKey.cursorStartHaptic, store: SharedStore.defaults) private var cursorStart = SettingDefault.cursorStartHaptic
    @AppStorage(SettingKey.cursorTickHaptic, store: SharedStore.defaults) private var cursorTick = SettingDefault.cursorTickHaptic
    @AppStorage(SettingKey.clickSound, store: SharedStore.defaults) private var clicks = SettingDefault.clickSound

    private struct Feel {
        let name: String
        let sharpness: Double
        let strength: Double
    }

    private let feels = [Feel(name: "Soft", sharpness: 0.1, strength: 0.45),
                         Feel(name: "Light", sharpness: 0.3, strength: 0.38),
                         Feel(name: "Medium", sharpness: 0.5, strength: 0.55),
                         Feel(name: "Firm", sharpness: 0.7, strength: 0.75),
                         Feel(name: "Crisp", sharpness: 0.9, strength: 0.6)]

    private var isOn: Bool { return strength > 0.01 }

    private var feelIndex: Int? {
        return feels.firstIndex { abs($0.sharpness - sharpness) < 0.001 && abs($0.strength - strength) < 0.001 }
    }

    // The preview stays pinned above the settings (PinnedPreview).
    var body: some View {
        PinnedPreview(id: "haptics", height: 150) {
            HapticPreview()
        } content: {
        List {
            Section {
                Toggle(isOn: Binding(get: { isOn }, set: { on in
                    strength = on ? SettingDefault.vibration : 0
                    Feedback.tick()
                })) {
                    Label("Vibrate on key presses", systemImage: "iphone.radiowaves.left.and.right")
                }
                if isOn {
                    SegmentedChoice(title: "Feel", names: feels.map { $0.name }, selected: feelIndex, knock: false) { index in
                        sharpness = feels[index].sharpness
                        strength = feels[index].strength
                        Feedback.test(strength: strength, sharpness: sharpness)
                    }
                    GlassSlider(title: "Strength", symbol: "speaker.wave.2", value: $strength,
                                range: 0.1...1, step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
                    GlassSlider(title: "Sharpness", symbol: "waveform.path", value: $sharpness,
                                range: 0...1, step: 0.05) { value in
                        ["Soft", "Light", "Medium", "Firm", "Crisp"][min(4, max(0, Int(value * 5)))]
                    }
                }
            } header: {
                SectionHeader("Vibration", symbol: "iphone.radiowaves.left.and.right", color: .pink)
            } footer: {
                Text("Needs Full Access for the keyboard. Sharpness goes from a soft thud to a crisp tap.")
            }
            .glassRows()

            Section {
                GlassToggle(title: "When cursor mode starts",
                            subtitle: "One tick when holding the space bar turns it into a trackpad.",
                            isOn: $cursorStart)
                GlassToggle(title: "For each character",
                            subtitle: "A light tick for every character the cursor moves past.",
                            isOn: $cursorTick)
            } header: {
                SectionHeader("Cursor ticks", symbol: "character.cursor.ibeam", color: .teal)
            }
            .glassRows()

            Section {
                GlassToggle(title: "Key clicks", subtitle: "The system key sound, muted by the silent switch.",
                            isOn: $clicks)
            } header: {
                SectionHeader("Sound", symbol: "speaker.wave.2.fill", color: .orange)
            }
            .glassRows()
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        }
        .navigationTitle("Haptics")
        .navigationBarTitleDisplayMode(.inline)
    }
}
