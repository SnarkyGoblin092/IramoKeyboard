import SwiftUI

/// The editor of the chosen designed theme, in three tabs: Colours (the backdrop, the keys, the labels, the accent
/// and the line colour), Keys (corners, outline, how solid, frosted, sheen and depth) and Effects (shadow or glow,
/// glowing labels, the backdrop's texture). Every change is saved at once as the theme's edited style
/// (ThemeEdits, in the App Group defaults), so the pinned keyboard above and the keyboard itself follow it; Reset
/// puts the theme back as designed.
struct ThemeEditorView: View {
    enum Tab: Int, CaseIterable {
        case colours, keys, effects

        var title: String {
            switch self {
            case .colours: return tr("Colours")
            case .keys: return tr("Keys")
            case .effects: return tr("Effects")
            }
        }

        var symbol: String {
            switch self {
            case .colours: return "paintpalette"
            case .keys: return "square.on.square"
            case .effects: return "sparkles"
            }
        }
    }

    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.themeEdits, store: SharedStore.defaults) private var themeEdits = SettingDefault.themeEdits
    @State private var tab: Tab = .colours

    private var theme: ThemeDefinition { return ThemeCatalog.theme(id: themeID, edits: themeEdits) }

    var body: some View {
        PinnedPreview(height: 240, fills: true) {
            LiveKeyboard()
        } content: {
        GlassList {
            if let style = theme.style {
                Section {
                    EditorTabBar(selected: $tab)
                        .glassOutsideCard()
                }
                let edit = StyleEditor(theme: theme, style: style) { next in
                    themeEdits = ThemeEdits.setting(next, for: theme.id, in: themeEdits)
                }
                switch tab {
                case .colours: ThemeColoursTab(edit: edit)
                case .keys: ThemeKeysTab(edit: edit)
                case .effects: ThemeEffectsTab(edit: edit)
                }
                ThemeResetSection(theme: theme) {
                    themeEdits = ThemeEdits.setting(nil, for: theme.id, in: themeEdits)
                }
            } else {
                SystemThemeSections(theme: theme)
            }
        }
        .scrollContentBackground(.hidden)
        }
        .navigationTitle(tr("Customize %@", "\(theme.name)"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Editing

/// The theme being edited and how to save a change: bindings to each attribute of its style.
private struct StyleEditor {
    let theme: ThemeDefinition
    let style: ThemeStyle
    let save: (ThemeStyle) -> Void

    func binding<Value>(_ keyPath: WritableKeyPath<ThemeStyle, Value>) -> Binding<Value> {
        return Binding(get: { style[keyPath: keyPath] }, set: { value in
            var next = style
            next[keyPath: keyPath] = value
            save(next)
        })
    }

    /// A colour attribute as the system colour picker's Color. Every part keeps its own colour
    /// (ThemeStyle.separateColours), so a change never carries over to the parts that shared it.
    func colour(_ keyPath: WritableKeyPath<ThemeStyle, ThemeRGBA>) -> Binding<Color> {
        return Binding(get: { Color(style[keyPath: keyPath]) }, set: { color in
            let rgba = ThemeRGBA(color: color)
            guard rgba != style[keyPath: keyPath] else { return }
            var next = style
            next.separateColours()
            next[keyPath: keyPath] = rgba
            save(next)
        })
    }

    /// A part's own colour (`own`), shown as `shown` (what it is drawn with) while it has none.
    func colour(_ own: WritableKeyPath<ThemeStyle, ThemeRGBA?>, shown: KeyPath<ThemeStyle, ThemeRGBA>) -> Binding<Color> {
        return Binding(get: { Color(style[keyPath: shown]) }, set: { color in
            let rgba = ThemeRGBA(color: color)
            guard rgba != style[keyPath: shown] else { return }
            var next = style
            next.separateColours()
            next[keyPath: own] = rgba
            save(next)
        })
    }

    /// The theme drawn with another style (the option cards' pictures).
    func look(_ other: ThemeStyle) -> ThemeLook {
        var shown = theme
        shown.style = other
        return ThemeLook(theme: shown, accent: Color(other.accent), dark: other.isDark, roundness: other.roundness,
                         keySurface: SettingDefault.keySurface, keyBorderStyle: SettingDefault.keyBorderStyle,
                         keyGlow: SettingDefault.keyGlow, accentHex: "", accentName: SettingDefault.accent)
    }
}

private extension ThemeRGBA {
    init(color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        // Rounded to 8 bits, so a colour picked again compares equal and the stored edits stay short.
        func byte(_ value: CGFloat) -> Double { return (Double(min(max(value, 0), 1)) * 255).rounded() / 255 }
        self.init(byte(r), byte(g), byte(b), byte(a))
    }
}

/// The tabs, as the Emoji screen's.
private struct EditorTabBar: View {
    @Binding var selected: ThemeEditorView.Tab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ThemeEditorView.Tab.allCases, id: \.self) { tab in
                let isOn = tab == selected
                Button {
                    guard tab != selected else { return }
                    Feedback.choose()
                    selected = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol).font(.system(size: 18, weight: .medium))
                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundColor(isOn ? .white : .primary)
                    .glassTile(RoundedRectangle(cornerRadius: 14, style: .continuous), isOn: isOn)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

/// A colour of the theme with the system colour well.
private struct ColourRow: View {
    let title: String
    let subtitle: String
    @Binding var colour: Color
    var opacity = false

    var body: some View {
        ColorPicker(selection: $colour, supportsOpacity: opacity) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(subtitle).font(.footnote).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Colours

private struct ThemeColoursTab: View {
    let edit: StyleEditor

    var body: some View {
        Section {
            GlassToggle(title: tr("Transparent background"),
                        subtitle: tr("No backdrop behind the keys; the keys stay as they are."),
                        isOn: edit.binding(\.transparentBackdrop))
            ColourRow(title: tr("Top"), subtitle: tr("The backdrop's colour at the top."), colour: edit.colour(\.background))
            ColourRow(title: tr("Bottom"), subtitle: tr("Where the gradient ends; the same colour twice makes it plain."),
                      colour: edit.colour(\.backgroundEnd))
            // A plain backdrop has no gradient to turn.
            if edit.style.background != edit.style.backgroundEnd {
                let directions = ThemeStyle.GradientDirection.allCases
                SegmentedChoice(title: tr("Gradient"),
                                names: [tr("Down"), tr("Diagonal"), tr("Across"), tr("Radial")],
                                selected: directions.firstIndex(of: edit.style.gradient)) {
                    edit.binding(\.gradient).wrappedValue = directions[$0]
                }
            }
        } header: {
            SectionHeader(tr("Backdrop"), symbol: "rectangle.fill", color: .indigo)
        } footer: {
            Text((edit.style.isDark ? tr("A dark backdrop: the keyboard is in dark mode.") : tr("A light backdrop: the keyboard is in light mode."))
                 + (edit.style.transparentBackdrop ? " " + tr("While it's transparent, its colours only set light or dark mode.") : ""))
        }
        .glassRows()

        Section {
            ColourRow(title: tr("Letter keys"), subtitle: tr("Letters and numbers."), colour: edit.colour(\.key))
            ColourRow(title: tr("Space bar"), subtitle: tr("The space bar."), colour: edit.colour(\.spaceColour, shown: \.space))
            ColourRow(title: tr("Function keys"), subtitle: tr("Shift, delete, 123 and the emoji key."), colour: edit.colour(\.function))
            ColourRow(title: tr("Return key"), subtitle: tr("The return key."), colour: edit.colour(\.returnColour, shown: \.returnKey))
            ColourRow(title: tr("Shift when on"), subtitle: tr("Shift and caps lock while they're on."),
                      colour: edit.colour(\.shiftColour, shown: \.shiftOn))
        } header: {
            SectionHeader(tr("Keys"), symbol: "keyboard.fill", color: .blue)
        }
        .glassRows()

        Section {
            ColourRow(title: tr("Letters"), subtitle: tr("Letters, numbers and the space bar's name."), colour: edit.colour(\.text))
            ColourRow(title: tr("Function key symbols"), subtitle: tr("Shift, delete, 123 and the emoji key."),
                      colour: edit.colour(\.functionTextColour, shown: \.functionText))
            ColourRow(title: tr("Return key label"), subtitle: tr("The word or arrow on the return key."),
                      colour: edit.colour(\.returnTextColour, shown: \.returnText))
            ColourRow(title: tr("Shift symbol when on"), subtitle: tr("The arrow on shift and caps lock while they're on."),
                      colour: edit.colour(\.shiftTextColour, shown: \.shiftText))
            ColourRow(title: tr("Accent hints"), subtitle: tr("The small accent in a key's corner."),
                      colour: edit.colour(\.hintColour, shown: \.hint), opacity: true)
        } header: {
            SectionHeader(tr("Labels"), symbol: "textformat", color: .orange)
        }
        .glassRows()

        Section {
            ColourRow(title: tr("Words"), subtitle: tr("The suggested words."),
                      colour: edit.colour(\.suggestionTextColour, shown: \.suggestionText))
            ColourRow(title: tr("Pill"), subtitle: tr("Behind the word space will write, and a word you press."),
                      colour: edit.colour(\.pillColour, shown: \.pill))
            ColourRow(title: tr("Word on the pill"), subtitle: tr("The word on the pill."),
                      colour: edit.colour(\.pillTextColour, shown: \.pillText))
            ColourRow(title: tr("Buttons"), subtitle: tr("Functions and hide keyboard, at the bar's ends."),
                      colour: edit.colour(\.barIconColour, shown: \.barIcons))
        } header: {
            SectionHeader(tr("Suggestion bar"), symbol: "text.line.first.and.arrowtriangle.forward", color: .indigo)
        }
        .glassRows()

        Section {
            ColourRow(title: tr("Outlines"), subtitle: tr("The line round each key."),
                      colour: edit.colour(\.outlineColour, shown: \.outline), opacity: true)
            ColourRow(title: tr("Texture"), subtitle: tr("The backdrop's pattern."),
                      colour: edit.colour(\.textureColour, shown: \.textureInk), opacity: true)
                .disabled(edit.style.transparentBackdrop)
                .opacity(edit.style.transparentBackdrop ? 0.45 : 1)
            ColourRow(title: tr("Block shadow"), subtitle: tr("The hard shadow of the Block shadow."),
                      colour: edit.colour(\.blockShadowColour, shown: \.blockShadow))
            ColourRow(title: tr("Glow"), subtitle: tr("The halo of the Glow shadow."),
                      colour: edit.colour(\.glowColour, shown: \.glowShadow))
            ColourRow(title: tr("Swipe trail"), subtitle: tr("The line your finger draws while swiping."),
                      colour: edit.colour(\.trailColour, shown: \.trail))
            ColourRow(title: tr("Other highlights"), subtitle: tr("Key pop-up choices and everything else in the accent."),
                      colour: edit.colour(\.accent))
        } header: {
            SectionHeader(tr("Lines and effects"), symbol: "sparkles", color: .purple)
        }
        .glassRows()
    }
}

// MARK: - Keys

private struct ThemeKeysTab: View {
    let edit: StyleEditor
    @AppStorage(SettingKey.keyHeight, store: SharedStore.defaults) private var keyHeight = SettingDefault.keyHeight
    @AppStorage(SettingKey.keyGap, store: SharedStore.defaults) private var keyGap = SettingDefault.keyGap

    private let corners: [Double] = [0, 0.12, 0.26, 0.45, 1]

    private func same(_ a: Double, _ b: Double) -> Bool { return abs(a - b) < 0.001 }

    var body: some View {
        let roundness = edit.binding(\.roundness)
        Section {
            SegmentedChoice(names: [tr("Square"), tr("Slight"), tr("Standard"), tr("Soft"), tr("Pill")],
                            selected: corners.firstIndex { same($0, roundness.wrappedValue) }) { roundness.wrappedValue = corners[$0] }
            GlassSlider(title: tr("Roundness"), symbol: "app", value: roundness, range: 0...1, step: 0.02) {
                // The corner radius of a letter key (a share of half its shorter side, Theme.keyCornerRadius).
                DeviceMetrics.points($0 * min(DeviceMetrics.letterKeyWidth(keyGap: keyGap), keyHeight) / 2)
            }
            GlassSlider(title: tr("Outline"), symbol: "square.dashed", value: edit.binding(\.borderWidth),
                        range: ThemeStyle.borderWidthRange, step: 0.1) { $0 < 0.05 ? tr("None") : String(format: "%.1f pt", $0) }
        } header: {
            SectionHeader(tr("Shape"), symbol: "app", color: .indigo)
        }
        .glassRows()

        Section {
            GlassSlider(title: tr("Solid"), symbol: "circle.lefthalf.filled", value: edit.binding(\.keyOpacity),
                        range: 0...1, step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
            // Frosting only shows through keys that aren't fully solid.
            if edit.style.keyOpacity < 0.999 {
                GlassToggle(title: tr("Frosted"),
                            subtitle: tr("Blurs the backdrop behind each key, like frosted glass."),
                            isOn: edit.binding(\.frosted))
            }
            GlassSlider(title: tr("Sheen"), symbol: "sun.max", value: edit.binding(\.sheen), range: 0...1, step: 0.05) {
                DeviceMetrics.level($0, in: 0...1)
            }
            GlassSlider(title: tr("Depth"), symbol: "square.bottomhalf.filled", value: edit.binding(\.depth), range: 0...1, step: 0.05) {
                DeviceMetrics.level($0, in: 0...1)
            }
        } header: {
            SectionHeader(tr("Surface"), symbol: "square.fill.on.square.fill", color: .teal)
        } footer: {
            Text(tr("Sheen lights the top of each key; Depth shades it toward the bottom."))
        }
        .glassRows()
    }
}

// MARK: - Effects

private struct ThemeEffectsTab: View {
    let edit: StyleEditor

    private let shadows: [(value: ThemeStyle.Shadow, title: String)] = [
        (.none, tr("None")), (.soft, tr("Soft")), (.lift, tr("Lift")), (.block, tr("Block")), (.glow, tr("Glow"))
    ]
    private let textures: [(value: ThemeStyle.Texture, title: String)] = [
        (.none, tr("None")), (.dots, tr("Dots")), (.grid, tr("Grid")), (.lines, tr("Lines")),
        (.scanlines, tr("Scanlines")), (.diagonal, tr("Stripes")), (.checker, tr("Checks")), (.crosses, tr("Crosses"))
    ]
    private let textureColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    /// The theme with another shadow (at a strength that shows it), for that option's picture.
    private func withShadow(_ shadow: ThemeStyle.Shadow) -> ThemeStyle {
        var shown = edit.style
        shown.shadow = shadow
        shown.shadowStrength = max(shown.shadowStrength, 0.6)
        return shown
    }

    private func withTexture(_ texture: ThemeStyle.Texture) -> ThemeStyle {
        var shown = edit.style
        shown.texture = texture
        shown.textureStrength = max(shown.textureStrength, 0.7)
        return shown
    }

    var body: some View {
        let style = edit.style
        Section {
            HStack(spacing: 6) {
                ForEach(shadows.indices, id: \.self) { index in
                    let option = shadows[index]
                    OptionCard(title: option.title, isOn: style.shadow == option.value) {
                        guard style.shadow != option.value else { return }
                        Feedback.choose()
                        var next = style
                        next.shadow = option.value
                        // A shadow chosen at no strength would show nothing.
                        if option.value != .none && next.shadowStrength < 0.05 { next.shadowStrength = 0.6 }
                        edit.save(next)
                    } picture: {
                        EffectSwatch(look: edit.look(withShadow(option.value)))
                    }
                }
            }
            .padding(.vertical, 4)
            if style.shadow != .none {
                GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: edit.binding(\.shadowStrength), range: 0...1, step: 0.05) {
                    DeviceMetrics.level($0, in: 0...1)
                }
            }
        } header: {
            SectionHeader(tr("Shadow"), symbol: "shadow", color: .purple)
        } footer: {
            Text(tr("Lift gives each key a solid edge in a deeper shade; Block a hard offset shadow in the line colour; Glow a halo in the accent."))
        }
        .glassRows()

        Section {
            let weights = Array(ThemeStyle.labelWeightRange)
            SegmentedChoice(title: tr("Weight"), names: [tr("Thin"), tr("Light"), tr("Normal"), tr("Medium"), tr("Bold"), tr("Heavy")],
                            selected: weights.firstIndex(of: style.labelWeight)) {
                edit.binding(\.labelWeight).wrappedValue = weights[$0]
            }
            GlassSlider(title: tr("Label glow"), symbol: "lightbulb.max", value: edit.binding(\.textGlow), range: 0...1, step: 0.05) {
                DeviceMetrics.level($0, in: 0...1)
            }
        } header: {
            SectionHeader(tr("Labels"), symbol: "textformat", color: .orange)
        } footer: {
            Text(tr("How heavy the letters and symbols are, and a neon halo around them in their own colour."))
        }
        .glassRows()

        Section {
            LazyVGrid(columns: textureColumns, spacing: 6) {
                ForEach(textures.indices, id: \.self) { index in
                    let option = textures[index]
                    OptionCard(title: option.title, isOn: style.texture == option.value) {
                        guard style.texture != option.value else { return }
                        Feedback.choose()
                        var next = style
                        next.texture = option.value
                        if option.value != .none && next.textureStrength < 0.05 { next.textureStrength = 0.5 }
                        edit.save(next)
                    } picture: {
                        EffectSwatch(look: edit.look(withTexture(option.value)), showsKey: false)
                    }
                }
            }
            .padding(.vertical, 4)
            if style.texture != .none {
                GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: edit.binding(\.textureStrength), range: 0...1, step: 0.05) {
                    DeviceMetrics.level($0, in: 0...1)
                }
            }
        } header: {
            SectionHeader(tr("Texture"), symbol: "circle.grid.3x3.fill", color: .teal)
        } footer: {
            Text(style.transparentBackdrop ? tr("The backdrop is transparent, so there is no texture to show.")
                 : tr("A pattern on the backdrop, in the texture colour."))
        }
        // A transparent backdrop draws no texture.
        .disabled(style.transparentBackdrop)
        .opacity(style.transparentBackdrop ? 0.45 : 1)
        .glassRows()
    }
}

/// An option card's picture: a piece of the theme's backdrop with one of its keys, drawn with the option.
private struct EffectSwatch: View {
    let look: ThemeLook
    var showsKey = true

    var body: some View {
        ZStack {
            look.backdrop(scale: 0.7)
            if showsKey {
                ZStack {
                    look.keyShape(.letter, radius: look.radius(width: 26, height: 30), scale: 0.8)
                    Text("A")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(look.textColor)
                        .keyLabelGlow(look, color: look.textColor, scale: 0.8)
                }
                .frame(width: 26, height: 30)
            }
        }
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Reset

private struct ThemeResetSection: View {
    let theme: ThemeDefinition
    let reset: () -> Void
    @State private var confirming = false

    var body: some View {
        Section {
            Button(role: .destructive) {
                Feedback.warning()
                confirming = true
            } label: {
                Label(tr("Reset %@", "\(theme.name)"), systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(ActionButtonStyle())   // its red glass capsule, standing on the backdrop without a card
            .disabled(!theme.isEdited)
            .glassOutsideCard()
            .confirmationDialog(tr("Put %@ back as designed?", "\(theme.name)"), isPresented: $confirming, titleVisibility: .visible) {
                Button(tr("Reset %@", "\(theme.name)"), role: .destructive) {
                    Feedback.delete()
                    reset()
                }
                Button(tr("Cancel"), role: .cancel) {}
            } message: {
                Text(tr("Its colours, keys and effects go back to the theme's own. Other themes keep their changes."))
            }
        } footer: {
            Text(theme.isEdited
                 ? tr("Changes are saved as you make them and kept for this theme, even when you switch to another one.")
                 : tr("%@ is as designed. Changes are saved as you make them.", "\(theme.name)"))
        }
        .glassRows()
    }
}
