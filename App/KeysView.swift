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

    private func same(_ a: Double, _ b: Double) -> Bool { return abs(a - b) < 0.001 }

    private var styleIndex: Int? {
        return styles.firstIndex {
            same($0.height, keyHeight) && same($0.roundness, roundness) && same($0.keyGap, keyGap) && same($0.rowGap, rowGap)
        }
    }

    var body: some View {
        List {
            Section {
                ThemePreview(theme: ThemeCatalog.theme(id: themeID),
                             accent: Color.currentAccent(name: accentName, hex: accentHex),
                             cornerRadius: 14)
                    .aspectRatio(ThemePreview.aspectWithStrip, contentMode: .fit)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .padding(.vertical, 6)
                    .previewRow()
            } footer: {
                Text("Your keyboard with these settings, in the current theme.")
            }
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
                SegmentedChoice(names: ["Follow shift", "Always capitals"], selected: alwaysCapitals ? 1 : 0) {
                    alwaysCapitals = $0 == 1
                }
                GlassSlider(title: "Letter size", symbol: "textformat.size", value: $letterSize,
                            range: Settings.letterSizeRange, step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
            } header: {
                SectionHeader("Letters", symbol: "textformat", color: .orange)
            }
            .glassRows()

            Section {
                Picker(selection: Binding(get: { keyHints ? hintPosition : "off" }, set: { value in
                    Feedback.tick()
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
                } label: {
                    Label("Position", systemImage: "square.grid.3x3.topright.filled")
                }
                .pickerStyle(.menu)
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
                HStack {
                    TextField("The language's name", text: Binding(get: { spaceText },
                                                                    set: { spaceText = String($0.prefix(32)) }))
                    if !spaceText.isEmpty {
                        Button {
                            Feedback.tick()
                            spaceText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear")
                    }
                }
                GlassSlider(title: "Text size", symbol: "textformat.size", value: $spaceTextSize,
                            range: Settings.spaceTextSizeRange, step: 1) { "\(Int($0.rounded())) pt" }
                GlassToggle(title: "Short language code",
                            subtitle: "EN, HU... instead of the language's full name.",
                            isOn: $spaceLanguageCode)
                    .disabled(!spaceText.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: {
                SectionHeader("Space bar", symbol: "space", color: .gray)
            } footer: {
                Text("Up to 32 characters. Leave it empty to show the language.")
            }
            .glassRows()
        }
        .listStyle(.insetGrouped)
        .glassScreen()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Keys")
        .navigationBarTitleDisplayMode(.inline)
    }
}
