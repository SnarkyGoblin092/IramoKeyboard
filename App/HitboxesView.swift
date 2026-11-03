import SwiftUI

/// Where a tap counts as which key: how much room the letters get next to the other keys, adaptive keys (the
/// letters likely to come next get more) and the hit map (learned from where the user really taps). The keyboard
/// reads the same settings (Prefs, KeyboardView.hitScore).
struct HitboxesView: View {
    @AppStorage(SettingKey.hitboxSize, store: SharedStore.defaults) private var size = SettingDefault.hitboxSize
    @AppStorage(SettingKey.keyGap, store: SharedStore.defaults) private var keyGap = SettingDefault.keyGap
    @AppStorage(SettingKey.adaptiveHitboxes, store: SharedStore.defaults) private var adaptive = SettingDefault.adaptiveHitboxes
    @AppStorage(SettingKey.adaptiveGrow, store: SharedStore.defaults) private var grow = SettingDefault.adaptiveGrow
    @AppStorage(SettingKey.adaptiveShrink, store: SharedStore.defaults) private var shrink = SettingDefault.adaptiveShrink
    @AppStorage(SettingKey.adaptiveStrength, store: SharedStore.defaults) private var strength = SettingDefault.adaptiveStrength
    @AppStorage(SettingKey.adaptiveWordStart, store: SharedStore.defaults) private var wordStart = SettingDefault.adaptiveWordStart
    @AppStorage(SettingKey.hitMap, store: SharedStore.defaults) private var hitMap = SettingDefault.hitMap
    @AppStorage(SettingKey.hitMapStrength, store: SharedStore.defaults) private var hitMapStrength = SettingDefault.hitMapStrength

    /// What the preview draws over the keys: 0 the touch areas, 1 the hit map.
    @AppStorage("hitboxPreviewMode") private var previewMode = 0

    private let sizes: [Double] = [0.85, 1.0, 1.2]

    private struct Adaptive {
        let grow: Double
        let shrink: Double
        let strength: Double
    }

    private let adaptiveLevels = [Adaptive(grow: 0.20, shrink: 0.10, strength: 0.50),
                                  Adaptive(grow: 0.35, shrink: 0.20, strength: 0.65),
                                  Adaptive(grow: 0.50, shrink: 0.30, strength: 0.85)]

    private func same(_ a: Double, _ b: Double) -> Bool { return abs(a - b) < 0.001 }

    /// A letter key's width on this phone, which the room settings are shares of.
    private var keyWidth: Double { return DeviceMetrics.letterKeyWidth(keyGap: keyGap) + keyGap }

    private var sizeFooter: String {
        let room = DeviceMetrics.points(keyWidth * size)
        if size < 0.999 {
            return tr("Letters take %@ of room each: shift, delete and space take more of the edges next to them.", "\(room)")
        }
        if size > 1.001 {
            return tr("Letters take %@ of room each: they take more of the edges next to shift, delete and space.", "\(room)")
        }
        return tr("Every key gets exactly the room it is drawn with.")
    }

    // The preview stays pinned above the settings (PinnedPreview).
    var body: some View {
        PinnedPreview(id: "hitboxes", height: 260, fills: true) {
            VStack(spacing: 8) {
                SegmentedChoice(names: [tr("Hitboxes"), tr("Hit map")], selected: previewMode) { previewMode = $0 }
                    .padding(.horizontal)
                LiveKeyboard(showsHitboxes: true, hitboxMode: previewMode == 1 ? .hitMap : .hitboxes)
            }
        } content: {
        GlassList {
            Section {
                SegmentedChoice(names: [tr("Strict"), tr("Normal"), tr("Generous")],
                                selected: sizes.firstIndex { same($0, size) }) { size = sizes[$0] }
                GlassSlider(title: tr("Letter room"), symbol: "square.dashed", value: $size,
                            range: Settings.hitboxSizeRange, step: 0.05) { DeviceMetrics.points(keyWidth * $0) }
            } header: {
                SectionHeader(tr("Letter keys"), symbol: "square.dashed", color: .blue)
            } footer: {
                Text(sizeFooter)
            }
            .glassRows()

            Section {
                GlassToggle(title: tr("Adaptive keys"),
                            subtitle: tr("The letters you're likely to type next get more room, the unlikely ones less."),
                            isOn: $adaptive, feature: .keyLearning)
                Group {
                    SegmentedChoice(names: [tr("Gentle"), tr("Normal"), tr("Strong")],
                                    selected: adaptiveLevels.firstIndex {
                                        same($0.grow, grow) && same($0.shrink, shrink) && same($0.strength, strength)
                                    }) { index in
                        grow = adaptiveLevels[index].grow
                        shrink = adaptiveLevels[index].shrink
                        strength = adaptiveLevels[index].strength
                    }
                    GlassToggle(title: tr("Before the first letter"),
                                subtitle: tr("Favour the letters words usually begin with."),
                                isOn: $wordStart)
                    GlassSlider(title: tr("Likely letters"), symbol: "plus.magnifyingglass", value: $grow,
                                range: Settings.adaptiveGrowRange, step: 0.05) { "+" + DeviceMetrics.points(keyWidth * $0) }
                    GlassSlider(title: tr("Unlikely letters"), symbol: "minus.magnifyingglass", value: $shrink,
                                range: Settings.adaptiveShrinkRange, step: 0.05) { "\u{2212}" + DeviceMetrics.points(keyWidth * $0) }
                    GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: $strength,
                                range: 0...1, step: 0.05) { DeviceMetrics.level($0, in: 0...1) }
                }
                .disabled(!adaptive || EnabledLanguages.shared.lacking(.keyLearning).all)
                .opacity(adaptive && !EnabledLanguages.shared.lacking(.keyLearning).all ? 1 : 0.45)
            } header: {
                SectionHeader(tr("Adaptive keys"), symbol: "sparkles", color: .purple)
            } footer: {
                Text(tr("The middle of a key always types that key, however the room around it shifts. Type a few letters on the keyboard above to see the room change."))
            }
            .glassRows()

            HitMapSection(isOn: $hitMap, strength: $hitMapStrength)
        }
        .scrollContentBackground(.hidden)
        }
        .navigationTitle(tr("Hitboxes"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Hit map

/// What the keyboard learned about where the user taps: one dot per key, at the average tap position.
private struct HitMapSection: View {
    @Binding var isOn: Bool
    @Binding var strength: Double

    @State private var language: Language = HitMapSection.currentLanguage()
    @State private var data: [String: [Double]] = [:]
    @State private var confirmReset = false
    @Environment(\.scenePhase) private var scenePhase

    private static func currentLanguage() -> Language {
        return Language(rawValue: Settings.shared.languageCode) ?? .english
    }

    private var languages: [Language] {
        let enabled = Language.list(from: Settings.shared.enabledLanguages)
        return enabled.contains(language) ? enabled : [language] + enabled
    }

    private var samples: Int { return Int(data.values.reduce(0) { $0 + ($1.first ?? 0) }) }
    private var keysLearned: Int { return data.values.filter { ($0.first ?? 0) >= 8 }.count }

    var body: some View {
        Group {
        Section {
            GlassToggle(title: tr("Learn my taps"),
                        subtitle: tr("Notices where you really tap each key and moves its room there."),
                        isOn: $isOn, feature: .keyLearning)
            // The label beside a menu picker, as in a list (a menu picker alone shows only its value).
            // What was learned in that language, under its name.
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("Language"))
                        Text(tr("%1$@ taps learned \u{00B7} %2$@ keys moved", "\(samples)", "\(keysLearned)"))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                } icon: {
                    Image(systemName: "globe")
                }
                Spacer()
                Picker(tr("Language"), selection: $language) {
                    ForEach(languages, id: \.self) { language in
                        Text(language.localizedName).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: $strength,
                        range: 0...1, step: 0.05) { DeviceMetrics.level($0, in: 0...1) }
                .disabled(!isOn)
                .opacity(isOn ? 1 : 0.45)
        } header: {
            SectionHeader(tr("Hit map"), symbol: "scope", color: .teal)
        } footer: {
            Text(data.isEmpty
                 ? tr("Nothing learned yet. Type on the keyboard and come back.")
                 : tr("Each highlighted key shows where its room has moved to; a key moves once it has 8 taps."))
        }
        .glassRows()

        Section {
            Button(role: .destructive) {
                Feedback.tap()
                confirmReset = true
            } label: {
                Label(tr("Forget learned taps"), systemImage: "trash")
            }
            .buttonStyle(ActionButtonStyle())
            .disabled(data.isEmpty)
            .confirmationDialog(tr("Forget learned taps?"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(tr("Forget"), role: .destructive) {
                    Settings.shared.setHitMapData([:], for: language.rawValue)
                    data = [:]
                    Feedback.delete()
                }
                Button(tr("Cancel"), role: .cancel) {}
            } message: {
                Text(tr("Everything learned about your taps in %@ is forgotten.", "\(language.localizedName)"))
            }
            .glassOutsideCard()
        }
        .glassRows()
        }
        .onAppear { reload() }
        .onChange(of: language) { _ in reload() }
        .onChange(of: scenePhase) { phase in if phase == .active { reload() } }
    }

    private func reload() {
        Settings.shared.refresh()
        data = Settings.shared.hitMapData(for: language.rawValue)
    }
}
