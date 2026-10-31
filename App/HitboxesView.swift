import SwiftUI

/// The letter keys' touch areas: how big they are next to the other keys, adaptive keys (the letters likely to
/// come next grow) and the hit map (learned from where the user really taps). The keyboard reads the same
/// settings (Prefs, KeyboardView.hitScore).
struct HitboxesView: View {
    private enum Tab: Hashable { case size, adaptive, hitMap }

    @State private var tab: Tab = .size
    @AppStorage(SettingKey.hitboxSize, store: SharedStore.defaults) private var size = SettingDefault.hitboxSize
    @AppStorage(SettingKey.adaptiveHitboxes, store: SharedStore.defaults) private var adaptive = SettingDefault.adaptiveHitboxes
    @AppStorage(SettingKey.adaptiveGrow, store: SharedStore.defaults) private var grow = SettingDefault.adaptiveGrow
    @AppStorage(SettingKey.adaptiveShrink, store: SharedStore.defaults) private var shrink = SettingDefault.adaptiveShrink
    @AppStorage(SettingKey.adaptiveStrength, store: SharedStore.defaults) private var strength = SettingDefault.adaptiveStrength
    @AppStorage(SettingKey.adaptiveWordStart, store: SharedStore.defaults) private var wordStart = SettingDefault.adaptiveWordStart
    @AppStorage(SettingKey.hitMap, store: SharedStore.defaults) private var hitMap = SettingDefault.hitMap
    @AppStorage(SettingKey.hitMapStrength, store: SharedStore.defaults) private var hitMapStrength = SettingDefault.hitMapStrength
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex

    private struct SizePreset { let name: String; let value: Double }
    private let sizePresets = [SizePreset(name: "Precise", value: 0.85),
                               SizePreset(name: "Default", value: 1.0),
                               SizePreset(name: "Forgiving", value: 1.2)]

    private struct AdaptivePreset { let name: String; let grow: Double; let shrink: Double; let strength: Double }
    private let adaptivePresets = [AdaptivePreset(name: "Subtle", grow: 0.20, shrink: 0.10, strength: 0.50),
                                   AdaptivePreset(name: "Default", grow: 0.35, shrink: 0.20, strength: 0.65),
                                   AdaptivePreset(name: "Strong", grow: 0.50, shrink: 0.30, strength: 0.85)]

    private var sizeName: String {
        return sizePresets.first(where: { abs($0.value - size) < 0.001 })?.name ?? "Custom"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summary
                VStack(alignment: .leading, spacing: 16) {
                    GlassTabs(tabs: [Tab.size, .adaptive, .hitMap], selection: $tab,
                              title: { tab in
                                  switch tab {
                                  case .size: return "Size"
                                  case .adaptive: return "Adaptive"
                                  case .hitMap: return "Hit map"
                                  }
                              },
                              symbol: { tab in
                                  switch tab {
                                  case .size: return "square.dashed"
                                  case .adaptive: return "sparkles"
                                  case .hitMap: return "scope"
                                  }
                              },
                              marked: { tab in
                                  switch tab {
                                  case .size: return false
                                  case .adaptive: return adaptive
                                  case .hitMap: return hitMap
                                  }
                              })
                    Divider()
                    switch tab {
                    case .size: sizeTab
                    case .adaptive: adaptiveTab
                    case .hitMap: HitMapPanel(isOn: $hitMap, strength: $hitMapStrength)
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: GlassMetrics.cardRadius)
            }
            .padding(16)
        }
        .background(GlassBackdrop())
        .navigationTitle("Hitboxes")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Summary

    private var summary: some View {
        VStack(alignment: .leading, spacing: 16) {
            HitboxDemo(size: size,
                       grow: adaptive ? grow * strength : 0,
                       shrink: adaptive ? shrink * strength : 0)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(sizeName).font(.largeTitle.weight(.bold))
                Text("\(Int((size * 100).rounded()))%").font(.title3.weight(.semibold)).foregroundColor(.secondary)
            }
            HStack(spacing: 10) {
                chip("Adaptive", isOn: $adaptive)
                chip("Hit map", isOn: $hitMap)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: GlassMetrics.cardRadius, tint: Color.currentAccent(name: accentName, hex: accentHex))
    }

    private func chip(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            Feedback.tick()
            isOn.wrappedValue.toggle()
        } label: {
            Label(title, systemImage: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isOn.wrappedValue ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(isOn.wrappedValue ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.primary.opacity(0.08))))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isOn.wrappedValue ? .isSelected : [])
    }

    // MARK: Size

    private var sizeTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ForEach(sizePresets, id: \.name) { preset in
                    PresetCard(title: preset.name, isSelected: abs(preset.value - size) < 0.001) {
                        Feedback.tick()
                        size = preset.value
                    } picture: {
                        HStack(spacing: 10) {
                            MiniKey(hitbox: preset.value)
                            MiniKey(hitbox: preset.value)
                        }
                    }
                }
            }
            Text(sizeExplanation)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            GlassSlider(title: "Letter keys", symbol: "keyboard", value: $size,
                        range: Settings.hitboxSizeRange, step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
        }
    }

    private var sizeExplanation: String {
        if size < 0.999 {
            return "Letter touch areas \(Int((size * 100).rounded()))%: shift, delete and space take more of the edges between them and the letters."
        }
        if size > 1.001 {
            return "Letter touch areas \(Int((size * 100).rounded()))%: the letters take more of the edges next to shift, delete and space."
        }
        return "Letter touch areas match the keys you see."
    }

    // MARK: Adaptive

    private var adaptiveTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassToggle(title: "Adaptive keys",
                        subtitle: "The letters you're likely to type next get bigger touch areas, the unlikely ones smaller.",
                        isOn: $adaptive)
            Group {
                HStack(spacing: 10) {
                    ForEach(adaptivePresets, id: \.name) { preset in
                        let selected = abs(preset.grow - grow) < 0.001 && abs(preset.shrink - shrink) < 0.001
                            && abs(preset.strength - strength) < 0.001
                        PresetCard(title: preset.name, isSelected: selected) {
                            Feedback.tick()
                            grow = preset.grow
                            shrink = preset.shrink
                            strength = preset.strength
                        } picture: {
                            HStack(spacing: 6) {
                                MiniKey(hitbox: 1 - preset.shrink * preset.strength)
                                MiniKey(hitbox: 1 + preset.grow * preset.strength, letter: "e")
                                MiniKey(hitbox: 1 - preset.shrink * preset.strength)
                            }
                        }
                    }
                }
                Text("Grow +\(Int((grow * 100).rounded()))% · shrink −\(Int((shrink * 100).rounded()))% · strength \(Int((strength * 100).rounded()))%")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Divider()
                GlassToggle(title: "At the start of a word",
                            subtitle: "Favour the letters words usually begin with, before you have typed anything.",
                            isOn: $wordStart)
                GlassSlider(title: "Grow likely", symbol: "arrow.up.left.and.arrow.down.right", value: $grow,
                            range: Settings.adaptiveGrowRange, step: 0.05) { "+\(Int(($0 * 100).rounded()))%" }
                GlassSlider(title: "Shrink unlikely", symbol: "arrow.down.right.and.arrow.up.left", value: $shrink,
                            range: Settings.adaptiveShrinkRange, step: 0.05) { "−\(Int(($0 * 100).rounded()))%" }
                GlassSlider(title: "Strength", symbol: "dial.medium", value: $strength,
                            range: 0...1, step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
            }
            .disabled(!adaptive)
            .opacity(adaptive ? 1 : 0.45)
        }
    }
}

// MARK: - Pictures

/// A small key with its touch area drawn as a dashed outline (`hitbox` 1 = the key itself).
private struct MiniKey: View {
    let hitbox: Double
    var letter: String? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.primary.opacity(0.85))
            .frame(width: 22, height: 30)
            .overlay {
                if let letter = letter {
                    Text(letter).font(.system(size: 12, weight: .semibold)).foregroundStyle(.tint)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [3, 2.5]))
                    .foregroundStyle(.tint)
                    .frame(width: 22 * hitbox + 8, height: 30 * hitbox + 8)
            }
            .frame(width: 34, height: 44)
    }
}

/// Five keys as the word "the" is being typed: with adaptive keys on, the likely "e" claims more room and its
/// neighbours give some up; the dashed outlines are the touch areas.
private struct HitboxDemo: View {
    let size: Double
    let grow: Double
    let shrink: Double

    private let letters = ["w", "e", "r", "t", "y"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(letters, id: \.self) { letter in
                let likely = letter == "e"
                let factor = size * (likely ? 1 + grow : 1 - shrink)
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 46, height: 58)
                    Text(letter)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(likely ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .foregroundStyle(.tint)
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(likely ? AnyShapeStyle(TintShapeStyle().opacity(0.15)) : AnyShapeStyle(Color.clear)))
                        .frame(width: 52 * factor, height: 64 * factor)
                }
                .frame(width: 52, height: 72)
                .zIndex(likely ? 1 : 0)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: size)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: grow)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: shrink)
        .accessibilityHidden(true)
    }
}

// MARK: - Hit map

/// What the keyboard learned about where the user taps: one dot per key, at the average tap position.
private struct HitMapPanel: View {
    @Binding var isOn: Bool
    @Binding var strength: Double

    @State private var language: Language = HitMapPanel.currentLanguage()
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
        VStack(alignment: .leading, spacing: 14) {
            GlassToggle(title: "Hit map",
                        subtitle: "Learns where you really tap each key and moves its touch area there.",
                        isOn: $isOn)
            HStack(spacing: 10) {
                Picker("Language", selection: $language) {
                    ForEach(languages, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)
                Spacer()
                Button {
                    reload()
                    Feedback.tick()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .accessibilityLabel("Refresh")
                Button(role: .destructive) {
                    confirmReset = true
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.red.opacity(0.12)))
                }
                .disabled(data.isEmpty)
                .accessibilityLabel("Reset the hit map")
                .confirmationDialog("Reset the hit map?", isPresented: $confirmReset, titleVisibility: .visible) {
                    Button("Reset", role: .destructive) {
                        Settings.shared.setHitMapData([:], for: language.rawValue)
                        data = [:]
                        Feedback.tick()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Everything learned about your taps in \(language.displayName) is forgotten.")
                }
            }
            .buttonStyle(PressableStyle())

            Text(data.isEmpty
                 ? "Nothing learned yet. Type on the keyboard and come back."
                 : "Each dot is where you tap that key on average. Keys move once they have 8 taps.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HitMapDrawing(rows: ThemePreview.letterRows(for: language), data: data)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.primary.opacity(0.06)))

            HStack(spacing: 28) {
                stat(samples, "Taps learned")
                stat(keysLearned, "Keys moved")
            }

            GlassSlider(title: "Strength", symbol: "dial.medium", value: $strength,
                        range: 0...1, step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
                .disabled(!isOn)
                .opacity(isOn ? 1 : 0.45)
        }
        .onAppear { reload() }
        .onChange(of: language) { _ in reload() }
        .onChange(of: scenePhase) { phase in if phase == .active { reload() } }
    }

    private func stat(_ value: Int, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)").font(.title.weight(.bold)).monospacedDigit()
            Text(title).font(.footnote).foregroundColor(.secondary)
        }
    }

    private func reload() {
        Settings.shared.refresh()
        data = Settings.shared.hitMapData(for: language.rawValue)
    }
}

/// The letter rows with a dot per learned key, offset from the key's centre the way the user's taps are.
private struct HitMapDrawing: View {
    let rows: [[String]]
    let data: [String: [Double]]

    private var columns: Int { return max(rows.map { $0.count }.max() ?? 10, 1) }

    var body: some View {
        GeometryReader { geometry in
            let keyWidth = geometry.size.width / CGFloat(columns)
            let keyHeight = geometry.size.height / CGFloat(max(rows.count, 1))
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        ForEach(row, id: \.self) { letter in
                            key(letter, width: keyWidth, height: keyHeight)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .aspectRatio(CGFloat(columns) / (CGFloat(max(rows.count, 1)) * 1.35), contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func key(_ letter: String, width: CGFloat, height: CGFloat) -> some View {
        let entry = data[letter] ?? []
        let taps = entry.first ?? 0
        let x = entry.count == 3 ? CGFloat(entry[1]) : 0
        let y = entry.count == 3 ? CGFloat(entry[2]) : 0
        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.10))
                .padding(2.5)
            Text(letter.uppercased())
                .font(.system(size: min(width, height) * 0.42, weight: .medium))
                .foregroundColor(.secondary)
            if taps > 0 {
                Circle()
                    .fill(.tint)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5))
                    .opacity(min(1, 0.35 + taps / 12))
                    .offset(x: x * (width - 5), y: y * (height - 5))
            }
        }
        .frame(width: width, height: height)
    }
}
