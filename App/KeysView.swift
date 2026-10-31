import SwiftUI

/// How the keys look: their size, corners, the gaps between them, their labels and the space bar. The preview at
/// the top follows every change; the keyboard reads the same settings (Prefs, KeyboardView, KeyView).
struct KeysView: View {
    private enum Tab: Hashable { case size, corners, spacing, labels, space }

    @State private var tab: Tab = .size
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @AppStorage(SettingKey.keyHeight, store: SharedStore.defaults) private var keyHeight = SettingDefault.keyHeight
    @AppStorage(SettingKey.keyboardWidth, store: SharedStore.defaults) private var keyboardWidth = SettingDefault.keyboardWidth
    @AppStorage(SettingKey.landscapeSeparate, store: SharedStore.defaults) private var landscapeSeparate = SettingDefault.landscapeSeparate
    @AppStorage(SettingKey.landscapeKeyHeight, store: SharedStore.defaults) private var landscapeKeyHeight = SettingDefault.landscapeKeyHeight
    @AppStorage(SettingKey.keyRoundness, store: SharedStore.defaults) private var roundness = SettingDefault.keyRoundness
    @AppStorage(SettingKey.keyGap, store: SharedStore.defaults) private var keyGap = SettingDefault.keyGap
    @AppStorage(SettingKey.rowGap, store: SharedStore.defaults) private var rowGap = SettingDefault.rowGap
    @AppStorage(SettingKey.alwaysCapitals, store: SharedStore.defaults) private var alwaysCapitals = SettingDefault.alwaysCapitals
    @AppStorage(SettingKey.letterSize, store: SharedStore.defaults) private var letterSize = SettingDefault.letterSize
    @AppStorage(SettingKey.keyHints, store: SharedStore.defaults) private var keyHints = SettingDefault.keyHints
    @AppStorage(SettingKey.hintPosition, store: SharedStore.defaults) private var hintPosition = SettingDefault.hintPosition
    @AppStorage(SettingKey.hintSize, store: SharedStore.defaults) private var hintSize = SettingDefault.hintSize
    @AppStorage(SettingKey.spaceText, store: SharedStore.defaults) private var spaceText = SettingDefault.spaceText
    @AppStorage(SettingKey.spaceTextSize, store: SharedStore.defaults) private var spaceTextSize = SettingDefault.spaceTextSize
    @AppStorage(SettingKey.spaceLanguageCode, store: SharedStore.defaults) private var spaceLanguageCode = SettingDefault.spaceLanguageCode

    // MARK: Presets

    private struct Look {
        let name: String
        let text: String
        let height: Double
        let roundness: Double
        let keyGap: Double
        let rowGap: Double
    }

    private let looks = [
        Look(name: "Compact", text: "Smaller keys and tighter gaps, leaving more of the screen for your app.",
             height: 40, roundness: 0.2, keyGap: 4, rowGap: 8),
        Look(name: "Balanced", text: "The standard size, shape and spacing.",
             height: 45, roundness: 0.26, keyGap: 6, rowGap: 11),
        Look(name: "Roomy", text: "Bigger, rounder keys with more room around them.",
             height: 52, roundness: 0.6, keyGap: 8, rowGap: 14)
    ]

    private struct Choice {
        let name: String
        let value: Double
    }

    private struct Spacing {
        let name: String
        let key: Double
        let row: Double
    }

    private struct HintChoice {
        let name: String
        let value: String
    }

    private let heights = [Choice(name: "Small", value: 38), Choice(name: "Compact", value: 40),
                           Choice(name: "Default", value: 45), Choice(name: "Medium", value: 48),
                           Choice(name: "Large", value: 52), Choice(name: "Extra large", value: 56)]
    private let corners = [Choice(name: "Square", value: 0), Choice(name: "Subtle", value: 0.12),
                           Choice(name: "Default", value: 0.26), Choice(name: "Rounded", value: 1)]
    private let spacings = [Spacing(name: "Tight", key: 4, row: 8), Spacing(name: "Default", key: 6, row: 11),
                            Spacing(name: "Roomy", key: 8, row: 14), Spacing(name: "Spacious", key: 10, row: 17)]
    private let hintPositions = [HintChoice(name: "Top right", value: "topRight"),
                                 HintChoice(name: "Top center", value: "topCenter"),
                                 HintChoice(name: "Top left", value: "topLeft"),
                                 HintChoice(name: "Bottom right", value: "bottomRight"),
                                 HintChoice(name: "Bottom center", value: "bottomCenter"),
                                 HintChoice(name: "Bottom left", value: "bottomLeft")]

    private func same(_ a: Double, _ b: Double) -> Bool { return abs(a - b) < 0.001 }

    private var currentLook: Look? {
        return looks.first {
            same($0.height, keyHeight) && same($0.roundness, roundness) && same($0.keyGap, keyGap) && same($0.rowGap, rowGap)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ThemePreview(theme: ThemeCatalog.theme(id: themeID),
                             accent: Color.currentAccent(name: accentName, hex: accentHex),
                             cornerRadius: 18)
                    .aspectRatio(ThemePreview.aspectWithStrip, contentMode: .fit)
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                    .animation(.easeOut(duration: 0.2), value: keyHeight)

                VStack(alignment: .leading, spacing: 16) {
                    lookPicker
                    Divider()
                    GlassTabs(tabs: [Tab.size, .corners, .spacing, .labels, .space], selection: $tab,
                              title: { tab in
                                  switch tab {
                                  case .size: return "Size"
                                  case .corners: return "Corners"
                                  case .spacing: return "Spacing"
                                  case .labels: return "Labels"
                                  case .space: return "Space"
                                  }
                              },
                              symbol: { tab in
                                  switch tab {
                                  case .size: return "arrow.up.left.and.arrow.down.right"
                                  case .corners: return "app"
                                  case .spacing: return "square.split.2x2"
                                  case .labels: return "textformat"
                                  case .space: return "space"
                                  }
                              })
                    Divider()
                    switch tab {
                    case .size: sizeTab
                    case .corners: cornersTab
                    case .spacing: spacingTab
                    case .labels: labelsTab
                    case .space: spaceTab
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: GlassMetrics.cardRadius)
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(GlassBackdrop())
        .navigationTitle("Keys")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Look

    private var lookPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(looks, id: \.name) { look in
                    let selected = currentLook?.name == look.name
                    Button {
                        Feedback.tick()
                        withAnimation(.easeOut(duration: 0.2)) {
                            keyHeight = look.height
                            roundness = look.roundness
                            keyGap = look.keyGap
                            rowGap = look.rowGap
                        }
                    } label: {
                        Text(look.name)
                            .font(.headline)
                            .foregroundColor(selected ? .white : .primary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Capsule().fill(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.clear)))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(4)
            .background(Capsule().fill(Color.primary.opacity(0.07)))
            Text(currentLook?.text ?? "Your own mix of size, corners and spacing.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Size

    private var sizeTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(heights, id: \.name) { item in
                    PresetCard(title: item.name, isSelected: same(item.value, keyHeight)) {
                        Feedback.tick()
                        keyHeight = item.value
                    } picture: {
                        MiniKeys(height: 18 + (item.value - 38) * 0.9, radius: roundness, letters: ["a", "b"])
                    }
                }
            }
            Divider()
            GlassSlider(title: "Height", symbol: "arrow.up.and.down", value: $keyHeight,
                        range: Settings.keyHeightRange, step: 1) { "\(Int($0.rounded()))pt" }
            GlassSlider(title: "Width", symbol: "arrow.left.and.right", value: $keyboardWidth,
                        range: Settings.keyboardWidthRange, step: 0.01) { "\(Int(($0 * 100).rounded()))%" }
            GlassToggle(title: "Own size in landscape",
                        subtitle: "Off: landscape keys are two thirds of the portrait height.",
                        isOn: $landscapeSeparate)
            if landscapeSeparate {
                GlassSlider(title: "Landscape height", symbol: "rectangle.landscape.rotate", value: $landscapeKeyHeight,
                            range: Settings.landscapeKeyHeightRange, step: 1) { "\(Int($0.rounded()))pt" }
            }
        }
    }

    // MARK: Corners

    private var cornersTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(corners, id: \.name) { item in
                    PresetCard(title: item.name, isSelected: same(item.value, roundness)) {
                        Feedback.tick()
                        roundness = item.value
                    } picture: {
                        MiniKeys(height: 30, radius: item.value, letters: ["a"])
                    }
                }
            }
            Divider()
            GlassSlider(title: "Roundness", symbol: "app", value: $roundness, range: 0...1, step: 0.02) {
                "\(Int(($0 * 100).rounded()))%"
            }
        }
    }

    // MARK: Spacing

    private var spacingTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(spacings, id: \.name) { item in
                    PresetCard(title: item.name, isSelected: same(item.key, keyGap) && same(item.row, rowGap)) {
                        Feedback.tick()
                        keyGap = item.key
                        rowGap = item.row
                    } picture: {
                        VStack(spacing: item.row * 0.35) {
                            ForEach(0..<2, id: \.self) { _ in
                                HStack(spacing: item.key * 0.45) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(Color.primary.opacity(0.85))
                                            .frame(width: 11, height: 14)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Divider()
            GlassSlider(title: "Key gap", symbol: "arrow.left.and.right", value: $keyGap,
                        range: Settings.keyGapRange, step: 1) { "\(Int($0.rounded()))pt" }
            GlassSlider(title: "Row gap", symbol: "arrow.up.and.down", value: $rowGap,
                        range: Settings.rowGapRange, step: 1) { "\(Int($0.rounded()))pt" }
        }
    }

    // MARK: Labels

    private var labelsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                PresetCard(title: "Follow shift", isSelected: !alwaysCapitals) {
                    Feedback.tick()
                    alwaysCapitals = false
                } picture: {
                    MiniKeys(height: 30, radius: roundness, letters: ["a", "b", "c"])
                }
                PresetCard(title: "Always capitals", isSelected: alwaysCapitals) {
                    Feedback.tick()
                    alwaysCapitals = true
                } picture: {
                    MiniKeys(height: 30, radius: roundness, letters: ["A", "B", "C"])
                }
            }
            GlassSlider(title: "Letter size", symbol: "textformat.size", value: $letterSize,
                        range: Settings.letterSizeRange, step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
            Divider()
            VStack(alignment: .leading, spacing: 3) {
                Label("Accent hints", systemImage: "textformat.abc.dottedunderline").font(.body.weight(.semibold))
                Text("A small hint on a key shows the first accent holding it gives you.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                PresetCard(title: "Off", isSelected: !keyHints) {
                    Feedback.tick()
                    keyHints = false
                } picture: {
                    HintKey(position: nil)
                }
                ForEach(hintPositions, id: \.value) { item in
                    PresetCard(title: item.name, isSelected: keyHints && hintPosition == item.value) {
                        Feedback.tick()
                        keyHints = true
                        hintPosition = item.value
                    } picture: {
                        HintKey(position: item.value)
                    }
                }
            }
            GlassSlider(title: "Hint size", symbol: "textformat.size.smaller", value: $hintSize,
                        range: Settings.hintSizeRange, step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
                .disabled(!keyHints)
                .opacity(keyHints ? 1 : 0.45)
        }
    }

    // MARK: Space

    private var spaceTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Space bar text").font(.body.weight(.semibold))
                Spacer()
                Button {
                    Feedback.tick()
                    spaceText = ""
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(PressableStyle())
                .disabled(spaceText.isEmpty)
            }
            TextField("Language name", text: Binding(get: { spaceText },
                                                     set: { spaceText = String($0.prefix(32)) }))
                .multilineTextAlignment(.center)
                .font(.title3)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.07)))
            Text("Up to 32 characters. Leave it empty for the language.")
                .font(.footnote)
                .foregroundColor(.secondary)
            GlassSlider(title: "Text size", symbol: "textformat.size", value: $spaceTextSize,
                        range: Settings.spaceTextSizeRange, step: 1) { "\(Int($0.rounded()))pt" }
            Divider()
            GlassToggle(title: "Language code",
                        subtitle: "Show the language as a short code (EN, HU) instead of its name.",
                        isOn: $spaceLanguageCode)
                .disabled(!spaceText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

// MARK: - Pictures

/// A few small keys with letters, at a given height and corner roundness (0...1).
private struct MiniKeys: View {
    let height: Double
    let radius: Double
    let letters: [String]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(letters, id: \.self) { letter in
                let width: CGFloat = 22
                RoundedRectangle(cornerRadius: CGFloat(radius) * min(width, CGFloat(height)) / 2, style: .continuous)
                    .fill(Color.primary.opacity(0.85))
                    .frame(width: width, height: CGFloat(height))
                    .overlay(Text(letter).font(.system(size: 12)).foregroundColor(Color(.systemBackground)))
            }
        }
        .frame(height: 50)
    }
}

/// A key with its accent hint in one corner (nil = no hint).
private struct HintKey: View {
    let position: String?

    private var alignment: Alignment {
        switch position {
        case "topLeft": return .topLeading
        case "topCenter": return .top
        case "bottomRight": return .bottomTrailing
        case "bottomCenter": return .bottom
        case "bottomLeft": return .bottomLeading
        default: return .topTrailing
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.primary.opacity(0.85))
            .frame(width: 30, height: 36)
            .overlay(Text("e").font(.system(size: 15)).foregroundColor(Color(.systemBackground)))
            .overlay(alignment: alignment) {
                if position != nil {
                    Text("é").font(.system(size: 8)).foregroundColor(Color(.systemBackground).opacity(0.7)).padding(3)
                }
            }
    }
}
