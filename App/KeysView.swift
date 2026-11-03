import SwiftUI

/// How the keys look: their size, corners, the gaps between them, their letters, accent hints and the space bar.
/// The preview at the top follows every change; the keyboard reads the same settings (Prefs, KeyboardView,
/// KeyView).
struct KeysView: View {
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
    @AppStorage(SettingKey.extraKeys, store: SharedStore.defaults) private var extraKeys = SettingDefault.extraKeys
    @AppStorage(SettingKey.commaKey, store: SharedStore.defaults) private var commaKey = SettingDefault.commaKey
    @AppStorage(SettingKey.periodKey, store: SharedStore.defaults) private var periodKey = SettingDefault.periodKey
    @AppStorage(SettingKey.emojiKey, store: SharedStore.defaults) private var emojiKey = SettingDefault.emojiKey
    @AppStorage(SettingKey.commaHold, store: SharedStore.defaults) private var commaHold = SettingDefault.commaHold
    @AppStorage(SettingKey.periodHold, store: SharedStore.defaults) private var periodHold = SettingDefault.periodHold

    // MARK: Presets

    /// Size, corners and spacing together.
    private struct Style {
        let name: String
        let height: Double
        let roundness: Double
        let keyGap: Double
        let rowGap: Double
    }

    private let styles = [Style(name: tr("Small"), height: 40, roundness: 0.2, keyGap: 4, rowGap: 8),
                          Style(name: tr("Standard"), height: 45, roundness: 0.26, keyGap: 6, rowGap: 11),
                          Style(name: tr("Large"), height: 52, roundness: 0.6, keyGap: 8, rowGap: 14)]
    private let heights: [Double] = [38, 40, 45, 48, 52, 56]
    private let gaps: [(key: Double, row: Double)] = [(4, 8), (6, 11), (8, 14), (10, 17)]

    private func same(_ a: Double, _ b: Double) -> Bool { return abs(a - b) < 0.001 }

    /// The symbols a hold on a key offers, typed in a row ("" keeps the language's own).
    private func holdField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(tr("Language's own"), text: Binding(get: { text.wrappedValue }, set: { value in
                text.wrappedValue = Settings.holdSymbols(value).joined()
            }))
            .multilineTextAlignment(.trailing)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .font(.body.monospaced())
        }
    }

    /// The extra symbols picked, in order.
    private var pickedSymbols: [String] {
        return Array(extraKeys.map { String($0) }.prefix(Settings.extraKeysLimit))
    }

    private func toggleSymbol(_ symbol: String) {
        var picked = pickedSymbols
        if let index = picked.firstIndex(of: symbol) {
            picked.remove(at: index)
            Feedback.delete()
        } else if picked.count < Settings.extraKeysLimit {
            picked.append(symbol)
            Feedback.choose()
        } else {
            return
        }
        withAnimation(.easeOut(duration: 0.18)) { extraKeys = picked.joined() }
    }

    /// The bottom row as the letters page has it: the space bar, the three places for symbols (a picked symbol
    /// taps off; an empty place waits for one from below) and the full stop.
    private var symbolSlots: some View {
        let picked = pickedSymbols
        return HStack(spacing: 6) {
            Text(tr("space"))
                .font(.footnote.weight(.medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, minHeight: 46)
                .glassTile(RoundedRectangle(cornerRadius: 10, style: .continuous), isOn: false)
                .layoutPriority(1)
            ForEach(0..<Settings.extraKeysLimit, id: \.self) { index in
                if index < picked.count {
                    let symbol = picked[index]
                    Button { toggleSymbol(symbol) } label: {
                        Text(symbol)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(width: 46, height: 46)
                            .glassTile(RoundedRectangle(cornerRadius: 10, style: .continuous), isOn: true)
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.45))
                                    .offset(x: 5, y: -5)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(tr("Remove %@", symbol))
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .frame(width: 46, height: 46)
                        .overlay(Image(systemName: "plus").font(.footnote.weight(.semibold)).foregroundColor(.secondary))
                        .accessibilityHidden(true)
                }
            }
            Text(".")
                .font(.title3.weight(.medium))
                .foregroundColor(.secondary)
                .frame(width: 38, height: 46)
                .glassTile(RoundedRectangle(cornerRadius: 10, style: .continuous), isOn: false)
        }
        .padding(.vertical, 4)
    }

    /// A symbol to pick: lit, with its place number, when it is one of the picked ones.
    private func symbolChip(_ symbol: String) -> some View {
        let place = pickedSymbols.firstIndex(of: symbol)
        let isOn = place != nil
        let isFull = pickedSymbols.count >= Settings.extraKeysLimit
        return Button { toggleSymbol(symbol) } label: {
            Text(symbol)
                .font(.title3.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundColor(isOn ? .white : .primary)
                .glassTile(RoundedRectangle(cornerRadius: 10, style: .continuous), isOn: isOn)
                .overlay(alignment: .topLeading) {
                    if let place = place {
                        Text("\(place + 1)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(4)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(!isOn && isFull)
        .opacity(!isOn && isFull ? 0.4 : 1)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var styleIndex: Int? {
        return styles.firstIndex {
            same($0.height, keyHeight) && same($0.roundness, roundness) && same($0.keyGap, keyGap) && same($0.rowGap, rowGap)
        }
    }

    var body: some View {
        // The keyboard stays pinned above the settings, at a fixed size.
        PinnedPreview(id: "keys", height: 240, fills: true) {
            LiveKeyboard()
        } content: {
        GlassList {
            Section {
                SegmentedChoice(title: tr("Overall"), names: styles.map { $0.name }, selected: styleIndex) { index in
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
                     ? tr("Your own mix of size, corners and spacing.")
                     : tr("Sets the key size, corners and spacing together; change any of them below."))
            }
            .glassRows()

            Section {
                SegmentedChoice(names: heights.map { "\(Int($0))" },
                                selected: heights.firstIndex { same($0, keyHeight) }) { keyHeight = heights[$0] }
                GlassSlider(title: tr("Key height"), symbol: "arrow.up.and.down", value: $keyHeight,
                            range: Settings.keyHeightRange, step: 1) { "\(Int($0.rounded())) pt" }
                GlassSlider(title: tr("Keyboard width"), symbol: "arrow.left.and.right", value: $keyboardWidth,
                            range: Settings.keyboardWidthRange, step: 0.01) { DeviceMetrics.points(DeviceMetrics.portraitWidth * $0) }
                GlassToggle(title: tr("Own height in landscape"),
                            subtitle: tr("Off: landscape keys are two thirds of the portrait height."),
                            isOn: $landscapeSeparate)
                if landscapeSeparate {
                    GlassSlider(title: tr("Landscape key height"), symbol: "rectangle.landscape.rotate",
                                value: $landscapeKeyHeight, range: Settings.landscapeKeyHeightRange,
                                step: 1) { "\(Int($0.rounded())) pt" }
                }
            } header: {
                SectionHeader(tr("Size"), symbol: "arrow.up.left.and.arrow.down.right", color: .blue)
            }
            .glassRows()

            Section {
                SettingToggle(tr("Number row"), key: SettingKey.numberRow, defaultValue: SettingDefault.numberRow,
                              subtitle: tr("Numbers above the letters"))
                SettingToggle(tr("Key pop-ups"), key: SettingKey.keyPopups, defaultValue: SettingDefault.keyPopups,
                              subtitle: tr("The letter shows above your finger"))
                if isPad {
                    GlassToggle(title: tr("Split keyboard"),
                                subtitle: tr("The keys in two halves, one under each thumb, in every language."),
                                isOn: $split)
                }
                SegmentedChoice(title: tr("One-handed"), names: [tr("Off"), tr("Left hand"), tr("Right hand")],
                                selected: hands.firstIndex(of: oneHanded)) { oneHanded = hands[$0] }
                    .disabled(isPad && split)
                    .opacity(isPad && split ? 0.45 : 1)
            } header: {
                SectionHeader(tr("Layout"), symbol: "hand.raised.fingers.spread", color: .teal)
            } footer: {
                Text(isPad && split
                     ? tr("The split keyboard is used instead of the one-handed one.")
                     : tr("One-handed: a narrower keyboard against that side. Tap the arrow in the empty side to move it over."))
            }
            .glassRows()

            Section {
                SegmentedChoice(names: [tr("Narrow"), tr("Standard"), tr("Wide"), tr("Extra wide")],
                                selected: gaps.firstIndex { same($0.key, keyGap) && same($0.row, rowGap) }) { index in
                    keyGap = gaps[index].key
                    rowGap = gaps[index].row
                }
                GlassSlider(title: tr("Between keys"), symbol: "arrow.left.and.right", value: $keyGap,
                            range: Settings.keyGapRange, step: 1) { "\(Int($0.rounded())) pt" }
                GlassSlider(title: tr("Between rows"), symbol: "arrow.up.and.down", value: $rowGap,
                            range: Settings.rowGapRange, step: 1) { "\(Int($0.rounded())) pt" }
            } header: {
                SectionHeader(tr("Spacing"), symbol: "square.split.2x2", color: .teal)
            } footer: {
                Text(tr("The whole space between keys still takes taps; wider gaps only change how the keys look."))
            }
            .glassRows()

            Section {
                NavigationLink {
                    KeyFontChoice(keyFont: $keyFont)
                } label: {
                    HStack {
                        Label(tr("Font"), systemImage: "textformat.alt")
                        Spacer()
                        Text(tr(KeyFont.named(keyFont).displayName)).foregroundColor(.secondary)
                        DisclosureChevron()
                    }
                    .foregroundColor(.primary)
                    .contentShape(Rectangle())
                }
                VStack(alignment: .leading, spacing: 6) {
                    SegmentedChoice(names: [tr("Follow shift"), tr("Always capitals")], selected: alwaysCapitals ? 1 : 0) {
                        alwaysCapitals = $0 == 1
                    }
                    .disabled(languages.lacking(.capitals).all)
                    .opacity(languages.lacking(.capitals).all ? 0.45 : 1)
                    FeatureNote(.capitals)
                }
                GlassSlider(title: tr("Letter size"), symbol: "textformat.size", value: $letterSize,
                            range: Settings.letterSizeRange, step: 0.05) { DeviceMetrics.points(23 * $0) }
            } header: {
                SectionHeader(tr("Letters"), symbol: "textformat", color: .orange)
            } footer: {
                Text(tr("The font of the keys, their pop-ups and the suggestion bar. Letters a font lacks (Arabic, Cyrillic) use the system font."))
            }
            .glassRows()

            Section {
                // The label beside a menu picker, as in a list (a menu picker alone shows only its value).
                HStack {
                    Label(tr("Position"), systemImage: "square.grid.3x3.topright.filled")
                    Spacer()
                    Picker(tr("Position"), selection: Binding(get: { keyHints ? hintPosition : "off" }, set: { value in
                        Feedback.choose()
                        if value == "off" {
                            keyHints = false
                        } else {
                            keyHints = true
                            hintPosition = value
                        }
                    })) {
                        Text(tr("Off")).tag("off")
                        Text(tr("Top right")).tag("topRight")
                        Text(tr("Top centre")).tag("topCenter")
                        Text(tr("Top left")).tag("topLeft")
                        Text(tr("Bottom right")).tag("bottomRight")
                        Text(tr("Bottom centre")).tag("bottomCenter")
                        Text(tr("Bottom left")).tag("bottomLeft")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                GlassSlider(title: tr("Hint size"), symbol: "textformat.size.smaller", value: $hintSize,
                            range: Settings.hintSizeRange, step: 0.05) { DeviceMetrics.points(10 * $0) }
                    .disabled(!keyHints)
                    .opacity(keyHints ? 1 : 0.45)
            } header: {
                SectionHeader(tr("Accent hints"), symbol: "textformat.abc.dottedunderline", color: .pink)
            } footer: {
                Text(tr("A small mark on a key shows the first accent you get by holding it."))
            }
            .glassRows()

            Section {
                GlassSlider(title: tr("Text size"), symbol: "textformat.size", value: $spaceTextSize,
                            range: Settings.spaceTextSizeRange, step: 1) { "\(Int($0.rounded())) pt" }
                GlassToggle(title: tr("Short language code"),
                            subtitle: tr("EN, HU... instead of the language's full name."),
                            isOn: $spaceLanguageCode)
            } header: {
                SectionHeader(tr("Space bar"), symbol: "space", color: .gray)
            } footer: {
                Text(tr("The space bar shows the language you're typing in."))
            }
            .glassRows()

            Section {
                symbolSlots
                ForEach(Settings.extraKeyGroups.indices, id: \.self) { groupIndex in
                    let group = Settings.extraKeyGroups[groupIndex]
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tr(group.name)).font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                            ForEach(group.symbols, id: \.self) { symbol in
                                symbolChip(symbol)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                SectionHeader(tr("Symbol keys"), symbol: "at", color: .indigo)
            } footer: {
                Text(pickedSymbols.count >= Settings.extraKeysLimit
                     ? tr("All three places are taken: tap a symbol in the row above to free its place.")
                     : tr("Tap up to three symbols to give each its own key between the space bar and the full stop, in the order you pick them."))
            }
            .glassRows()

            Section {
                GlassToggle(title: tr("Emoji key"), subtitle: tr("Without it, the emoji are in the Functions panel when Emoji is one of its tools."),
                            isOn: $emojiKey)
                GlassToggle(title: tr("Comma key"), subtitle: tr("The comma left of the space bar."), isOn: $commaKey)
                if commaKey {
                    holdField(tr("Hold comma for"), text: $commaHold)
                }
                GlassToggle(title: tr("Full stop key"), subtitle: tr("The full stop right of the space bar."), isOn: $periodKey)
                if periodKey {
                    holdField(tr("Hold full stop for"), text: $periodHold)
                }
            } header: {
                SectionHeader(tr("Bottom row"), symbol: "keyboard.chevron.compact.down", color: .gray)
            } footer: {
                Text(tr("Keys you take off give their room to the space bar. Type the symbols a hold offers, in order (up to ten); leave it empty for your language's own."))
            }
            .glassRows()
        }
        .scrollContentBackground(.hidden)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(tr("Keys"))
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
                            Text(tr(font.displayName))
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
        .navigationTitle(tr("Font"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
