import SwiftUI

/// How the keys look: their size, corners, the gaps between them, their letters, accent hints and the space bar.
/// The preview at the top follows every change; the keyboard reads the same settings (Prefs, KeyboardView,
/// KeyView).
struct KeysView: View {
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @AppStorage(SettingKey.keyHeight, store: SharedStore.defaults) private var keyHeight = SettingDefault.keyHeight
    @AppStorage(SettingKey.keyboardWidth, store: SharedStore.defaults) private var keyboardWidth = SettingDefault.keyboardWidth
    @AppStorage(SettingKey.splitKeyboard, store: SharedStore.defaults) private var split = SettingDefault.splitKeyboard
    @AppStorage(SettingKey.oneHanded, store: SharedStore.defaults) private var oneHanded = SettingDefault.oneHanded
    private let hands = ["off", "left", "right"]
    private var isPad: Bool { return UIDevice.current.userInterfaceIdiom == .pad }
    @AppStorage(SettingKey.landscapeSeparate, store: SharedStore.defaults) private var landscapeSeparate = SettingDefault.landscapeSeparate
    @AppStorage(SettingKey.landscapeKeyHeight, store: SharedStore.defaults) private var landscapeKeyHeight = SettingDefault.landscapeKeyHeight
    @AppStorage(SettingKey.keyRoundness, store: SharedStore.defaults) private var roundness = SettingDefault.keyRoundness
    @AppStorage(SettingKey.keySurface, store: SharedStore.defaults) private var surface = SettingDefault.keySurface
    @AppStorage(SettingKey.keyBorderStyle, store: SharedStore.defaults) private var borderStyle = SettingDefault.keyBorderStyle
    @AppStorage(SettingKey.keyGlow, store: SharedStore.defaults) private var glow = SettingDefault.keyGlow
    @AppStorage(SettingKey.keyFont, store: SharedStore.defaults) private var keyFont = SettingDefault.keyFont
    @AppStorage(SettingKey.keyGap, store: SharedStore.defaults) private var keyGap = SettingDefault.keyGap
    @AppStorage(SettingKey.rowGap, store: SharedStore.defaults) private var rowGap = SettingDefault.rowGap
    @AppStorage(SettingKey.alwaysCapitals, store: SharedStore.defaults) private var alwaysCapitals = SettingDefault.alwaysCapitals
    @ObservedObject private var languages = EnabledLanguages.shared
    @AppStorage(SettingKey.letterSize, store: SharedStore.defaults) private var letterSize = SettingDefault.letterSize
    @AppStorage(SettingKey.keyHints, store: SharedStore.defaults) private var keyHints = SettingDefault.keyHints
    @AppStorage(SettingKey.hintPosition, store: SharedStore.defaults) private var hintPosition = SettingDefault.hintPosition
    @AppStorage(SettingKey.hintSize, store: SharedStore.defaults) private var hintSize = SettingDefault.hintSize
    @AppStorage(SettingKey.spaceTextSize, store: SharedStore.defaults) private var spaceTextSize = SettingDefault.spaceTextSize
    @AppStorage(SettingKey.spaceLanguageCode, store: SharedStore.defaults) private var spaceLanguageCode = SettingDefault.spaceLanguageCode

    // MARK: Presets

    /// Size, corners and spacing together.
    private struct Style {
        let name: String
        let height: Double
        let roundness: Double
        let keyGap: Double
        let rowGap: Double
    }

    private let styles = [Style(name: "Small", height: 40, roundness: 0.2, keyGap: 4, rowGap: 8),
                          Style(name: "Standard", height: 45, roundness: 0.26, keyGap: 6, rowGap: 11),
                          Style(name: "Large", height: 52, roundness: 0.6, keyGap: 8, rowGap: 14)]
    private let heights: [Double] = [38, 40, 45, 48, 52, 56]
    private let corners: [Double] = [0, 0.12, 0.26, 1]
    private let gaps: [(key: Double, row: Double)] = [(4, 8), (6, 11), (8, 14), (10, 17)]

    private let surfaces = ["auto", "flat", "sheen", "raised"]
    private let borders = ["auto", "none", "thin", "bold", "accent"]
    private let glows = ["off", "soft", "strong"]

    private func same(_ a: Double, _ b: Double) -> Bool { return abs(a - b) < 0.001 }

    /// The Liquid Glass theme on iOS 26: its keys are real glass, so the key style (surface, border, glow) has
    /// nothing to change (Theme.keySurface / drawsKeyBorder / keyGlow skip them); before iOS 26 they are drawn keys.
    private var glassKeys: Bool {
        guard ThemeCatalog.theme(id: themeID).kind == .liquidGlass else { return false }
        if #available(iOS 26, *) { return true }
        return false
    }

    private var styleIndex: Int? {
        return styles.firstIndex {
            same($0.height, keyHeight) && same($0.roundness, roundness) && same($0.keyGap, keyGap) && same($0.rowGap, rowGap)
        }
    }

    var body: some View {
        // The keyboard stays pinned above the settings, at a fixed size.
        PinnedPreview(id: "keys", height: 240, fills: true) {
            PinnedKeyboard()
        } content: {
        GlassList {
            Section {
                SegmentedChoice(title: "Overall", names: styles.map { $0.name }, selected: styleIndex) { index in
                    let style = styles[index]
                    withAnimation(.easeOut(duration: 0.2)) {
                        keyHeight = style.height
                        roundness = style.roundness
                        keyGap = style.keyGap
                        rowGap = style.rowGap
                    }
                }
            } footer: {
                Text(styleIndex == nil
                     ? "Your own mix of size, corners and spacing."
                     : "Sets the key size, corners and spacing together; change any of them below.")
            }
            .glassRows()

            Section {
                SegmentedChoice(names: heights.map { "\(Int($0))" },
                                selected: heights.firstIndex { same($0, keyHeight) }) { keyHeight = heights[$0] }
                GlassSlider(title: "Key height", symbol: "arrow.up.and.down", value: $keyHeight,
                            range: Settings.keyHeightRange, step: 1) { "\(Int($0.rounded())) pt" }
                GlassSlider(title: "Keyboard width", symbol: "arrow.left.and.right", value: $keyboardWidth,
                            range: Settings.keyboardWidthRange, step: 0.01) { "\(Int(($0 * 100).rounded()))%" }
                GlassToggle(title: "Own height in landscape",
                            subtitle: "Off: landscape keys are two thirds of the portrait height.",
                            isOn: $landscapeSeparate)
                if landscapeSeparate {
                    GlassSlider(title: "Landscape key height", symbol: "rectangle.landscape.rotate",
                                value: $landscapeKeyHeight, range: Settings.landscapeKeyHeightRange,
                                step: 1) { "\(Int($0.rounded())) pt" }
                }
            } header: {
                SectionHeader("Size", symbol: "arrow.up.left.and.arrow.down.right", color: .blue)
            }
            .glassRows()

            Section {
                if isPad {
                    GlassToggle(title: "Split keyboard",
                                subtitle: "The keys in two halves, one under each thumb, in every language.",
                                isOn: $split)
                }
                SegmentedChoice(title: "One-handed", names: ["Off", "Left hand", "Right hand"],
                                selected: hands.firstIndex(of: oneHanded)) { oneHanded = hands[$0] }
                    .disabled(isPad && split)
                    .opacity(isPad && split ? 0.45 : 1)
            } header: {
                SectionHeader("Layout", symbol: "hand.raised.fingers.spread", color: .teal)
            } footer: {
                Text(isPad && split
                     ? "The split keyboard is used instead of the one-handed one."
                     : "One-handed: a narrower keyboard against that side. Tap the arrow in the empty side to move it over.")
            }
            .glassRows()

            Section {
                SegmentedChoice(names: ["Square", "Slight", "Standard", "Round"],
                                selected: corners.firstIndex { same($0, roundness) }) { roundness = corners[$0] }
                GlassSlider(title: "Roundness", symbol: "app", value: $roundness, range: 0...1, step: 0.02) {
                    "\(Int(($0 * 100).rounded()))%"
                }
            } header: {
                SectionHeader("Corners", symbol: "app", color: .indigo)
            }
            .glassRows()

            Section {
                SegmentedChoice(title: "Surface", names: ["Auto", "Flat", "Sheen", "Raised"],
                                selected: surfaces.firstIndex(of: surface)) { surface = surfaces[$0] }
                SegmentedChoice(title: "Border", names: ["Auto", "None", "Thin", "Bold", "Accent"],
                                selected: borders.firstIndex(of: borderStyle)) { borderStyle = borders[$0] }
                SegmentedChoice(title: "Glow", names: ["Off", "Soft", "Strong"],
                                selected: glows.firstIndex(of: glow)) { glow = glows[$0] }
            } header: {
                SectionHeader("Key style", symbol: "sparkles", color: .purple)
            } footer: {
                Text(glassKeys
                     ? "Not used by the Liquid Glass theme: its keys are real glass, without a surface, outline or glow of their own. These apply again with any other theme."
                     : "Auto follows the theme: colour themes have raised keys, and every theme but Native a thin outline. Sheen lights the top of each key; Raised adds a shadow under it. Glow and Accent use the accent colour.")
            }
            .disabled(glassKeys)
            .opacity(glassKeys ? 0.45 : 1)
            .glassRows()

            Section {
                SegmentedChoice(names: ["Narrow", "Standard", "Wide", "Extra wide"],
                                selected: gaps.firstIndex { same($0.key, keyGap) && same($0.row, rowGap) }) { index in
                    keyGap = gaps[index].key
                    rowGap = gaps[index].row
                }
                GlassSlider(title: "Between keys", symbol: "arrow.left.and.right", value: $keyGap,
                            range: Settings.keyGapRange, step: 1) { "\(Int($0.rounded())) pt" }
                GlassSlider(title: "Between rows", symbol: "arrow.up.and.down", value: $rowGap,
                            range: Settings.rowGapRange, step: 1) { "\(Int($0.rounded())) pt" }
            } header: {
                SectionHeader("Spacing", symbol: "square.split.2x2", color: .teal)
            } footer: {
                Text("The whole space between keys still takes taps; wider gaps only change how the keys look.")
            }
            .glassRows()

            Section {
                NavigationLink {
                    KeyFontChoice(keyFont: $keyFont)
                } label: {
                    HStack {
                        Label("Font", systemImage: "textformat.alt")
                        Spacer()
                        Text(KeyFont.named(keyFont).displayName).foregroundColor(.secondary)
                        DisclosureChevron()
                    }
                    .foregroundColor(.primary)
                    .contentShape(Rectangle())
                }
                VStack(alignment: .leading, spacing: 6) {
                    SegmentedChoice(names: ["Follow shift", "Always capitals"], selected: alwaysCapitals ? 1 : 0) {
                        alwaysCapitals = $0 == 1
                    }
                    .disabled(languages.lacking(.capitals).all)
                    .opacity(languages.lacking(.capitals).all ? 0.45 : 1)
                    FeatureNote(.capitals)
                }
                GlassSlider(title: "Letter size", symbol: "textformat.size", value: $letterSize,
                            range: Settings.letterSizeRange, step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
            } header: {
                SectionHeader("Letters", symbol: "textformat", color: .orange)
            } footer: {
                Text("The font of the keys, their pop-ups and the suggestion bar. Letters a font lacks (Arabic, Cyrillic) use the system font.")
            }
            .glassRows()

            Section {
                // The label beside a menu picker, as in a list (a menu picker alone shows only its value).
                HStack {
                    Label("Position", systemImage: "square.grid.3x3.topright.filled")
                    Spacer()
                    Picker("Position", selection: Binding(get: { keyHints ? hintPosition : "off" }, set: { value in
                        Feedback.choose()
                        if value == "off" {
                            keyHints = false
                        } else {
                            keyHints = true
                            hintPosition = value
                        }
                    })) {
                        Text("Off").tag("off")
                        Text("Top right").tag("topRight")
                        Text("Top centre").tag("topCenter")
                        Text("Top left").tag("topLeft")
                        Text("Bottom right").tag("bottomRight")
                        Text("Bottom centre").tag("bottomCenter")
                        Text("Bottom left").tag("bottomLeft")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                GlassSlider(title: "Hint size", symbol: "textformat.size.smaller", value: $hintSize,
                            range: Settings.hintSizeRange, step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
                    .disabled(!keyHints)
                    .opacity(keyHints ? 1 : 0.45)
            } header: {
                SectionHeader("Accent hints", symbol: "textformat.abc.dottedunderline", color: .pink)
            } footer: {
                Text("A small mark on a key shows the first accent you get by holding it.")
            }
            .glassRows()

            Section {
                GlassSlider(title: "Text size", symbol: "textformat.size", value: $spaceTextSize,
                            range: Settings.spaceTextSizeRange, step: 1) { "\(Int($0.rounded())) pt" }
                GlassToggle(title: "Short language code",
                            subtitle: "EN, HU... instead of the language's full name.",
                            isOn: $spaceLanguageCode)
            } header: {
                SectionHeader("Space bar", symbol: "space", color: .gray)
            } footer: {
                Text("The space bar shows the language you're typing in.")
            }
            .glassRows()
        }
        .scrollContentBackground(.hidden)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Keys")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The keys' font, each name shown in that font; picking one goes back.
private struct KeyFontChoice: View {
    @Binding var keyFont: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GlassList {
            Section {
                ForEach(KeyFont.allCases, id: \.self) { font in
                    Button {
                        Feedback.choose()
                        keyFont = font.rawValue
                        dismiss()
                    } label: {
                        HStack {
                            Text(font.displayName)
                                .font(font.font(size: 17))
                                .foregroundColor(.primary)
                            Spacer()
                            if KeyFont.named(keyFont) == font {
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
        .navigationTitle("Font")
        .navigationBarTitleDisplayMode(.inline)
    }
}
