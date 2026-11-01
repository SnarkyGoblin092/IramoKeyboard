import SwiftUI

/// A miniature keyboard drawn from a `ThemeDefinition`, so the picker shows what the keyboard will look like.
/// It is drawn with the keyboard's own measurements, fonts and colours (light or dark, like the phone), as the
/// keyboard looks at the start of a sentence: shift on, capital letters.
struct ThemePreview: View {
    let theme: ThemeDefinition
    let accent: Color
    var showsStrip = true
    var cornerRadius: CGFloat = 14
    @AppStorage(SettingKey.keyRoundness, store: SharedStore.defaults) private var roundness = SettingDefault.keyRoundness
    @AppStorage(SettingKey.keySurface, store: SharedStore.defaults) private var keySurface = SettingDefault.keySurface
    @AppStorage(SettingKey.keyBorderStyle, store: SharedStore.defaults) private var keyBorderStyle = SettingDefault.keyBorderStyle
    @AppStorage(SettingKey.keyGlow, store: SharedStore.defaults) private var keyGlow = SettingDefault.keyGlow
    @AppStorage(SettingKey.keyHints, store: SharedStore.defaults) private var keyHints = SettingDefault.keyHints
    // The Keys and Suggestions screens' settings, drawn as the keyboard does.
    @AppStorage(SettingKey.keyGap, store: SharedStore.defaults) private var keyGap = SettingDefault.keyGap
    @AppStorage(SettingKey.rowGap, store: SharedStore.defaults) private var rowGap = SettingDefault.rowGap
    @AppStorage(SettingKey.keyboardWidth, store: SharedStore.defaults) private var keyboardWidth = SettingDefault.keyboardWidth
    @AppStorage(SettingKey.letterSize, store: SharedStore.defaults) private var letterSize = SettingDefault.letterSize
    @AppStorage(SettingKey.hintPosition, store: SharedStore.defaults) private var hintPosition = SettingDefault.hintPosition
    @AppStorage(SettingKey.hintSize, store: SharedStore.defaults) private var hintSize = SettingDefault.hintSize
    @AppStorage(SettingKey.spaceText, store: SharedStore.defaults) private var spaceText = SettingDefault.spaceText
    @AppStorage(SettingKey.spaceTextSize, store: SharedStore.defaults) private var spaceTextSize = SettingDefault.spaceTextSize
    @AppStorage(SettingKey.spaceLanguageCode, store: SharedStore.defaults) private var spaceLanguageCode = SettingDefault.spaceLanguageCode
    @AppStorage(SettingKey.suggestionHeight, store: SharedStore.defaults) private var suggestionHeight = SettingDefault.suggestionHeight
    @AppStorage(SettingKey.suggestionStyle, store: SharedStore.defaults) private var suggestionStyle = SettingDefault.suggestionStyle
    @AppStorage(SettingKey.separatorStyle, store: SharedStore.defaults) private var separatorStyle = SettingDefault.separatorStyle
    @AppStorage(SettingKey.suggestionFollowTheme, store: SharedStore.defaults) private var followTheme = SettingDefault.suggestionFollowTheme

    @Environment(\.colorScheme) private var systemScheme

    /// The language whose layout is drawn; defaults to the first enabled language, like the keyboard.
    var language: Language? = nil

    private var shownLanguage: Language {
        if let language = language { return language }
        let enabled = Language.list(from: Settings.shared.enabledLanguages)
        if let current = Language(rawValue: Settings.shared.languageCode), enabled.contains(current) { return current }
        return enabled.first ?? .english
    }

    private var letterRows: [[String]] { return ThemePreview.letterRows(for: shownLanguage) }

    // Mirrors `Language.letterRows` / `accents` in Keyboard/Layouts.swift (keyboard-only code, so copied here).
    // Also drawn by the hit map (HitboxesView).
    static func letterRows(for language: Language) -> [[String]] {
        func split(_ rows: String...) -> [[String]] { return rows.map { $0.map { String($0) } } }
        switch language {
        case .english, .italian: return split("qwertyuiop", "asdfghjkl", "zxcvbnm")
        case .hungarian, .czech: return split("qwertzuiop", "asdfghjkl", "yxcvbnm")
        case .spanish: return split("qwertyuiop", "asdfghjklñ", "zxcvbnm")
        case .french: return split("azertyuiop", "qsdfghjklm", "wxcvbn")
        case .german: return split("qwertzuiopü", "asdfghjklöä", "yxcvbnm")
        case .portuguese: return split("qwertyuiop", "asdfghjklç", "zxcvbnm")
        case .dutch, .polish, .romanian: return split("qwertyuiop", "asdfghjkl", "zxcvbnm")
        case .turkish: return split("qwertyuıopğü", "asdfghjklşi", "zxcvbnmöç")
        case .russian: return split("йцукенгшщзхъ", "фывапролджэ", "ячсмитьбю")
        case .ukrainian: return split("йцукенгшщзхї", "фівапролджє", "ячсмитьбюґ")
        case .swedish: return split("qwertyuiopå", "asdfghjklöä", "zxcvbnm")
        case .lithuanian: return split("qwertyuiop", "asdfghjkl", "zxcvbnm")
        case .arabic: return split("ضصثقفغعهخحجد", "شسيبلاتنمكط", "ذئءؤرىةوزظ")
        }
    }

    /// First long-press alternative of a key, shown as the small hint.
    private var hints: [String: String] {
        switch shownLanguage {
        case .hungarian: return ["a": "á", "e": "é", "i": "í", "o": "ó", "u": "ú"]
        case .spanish: return ["a": "á", "e": "é", "i": "í", "o": "ó", "u": "ú"]
        case .french: return ["a": "à", "e": "é", "i": "î", "o": "ô", "u": "ù", "y": "ÿ", "c": "ç"]
        case .german: return ["s": "ß", "e": "é"]
        case .italian: return ["a": "à", "e": "è", "i": "ì", "o": "ò", "u": "ù"]
        case .portuguese: return ["a": "á", "e": "é", "i": "í", "o": "ó", "u": "ú"]
        case .dutch: return ["a": "á", "e": "é", "i": "í", "o": "ó", "u": "ú"]
        case .polish: return ["a": "ą", "c": "ć", "e": "ę", "l": "ł", "n": "ń", "o": "ó", "s": "ś", "z": "ż"]
        case .czech: return ["a": "á", "c": "č", "d": "ď", "e": "é", "i": "í", "n": "ň", "o": "ó", "r": "ř", "s": "š", "t": "ť", "u": "ú", "y": "ý", "z": "ž"]
        case .romanian: return ["a": "ă", "i": "î", "s": "ș", "t": "ț"]
        case .turkish: return ["a": "â", "i": "î", "u": "û"]
        case .russian: return ["е": "ё"]
        case .swedish: return ["e": "é", "u": "ü"]
        case .lithuanian: return ["a": "ą", "c": "č", "e": "ę", "i": "į", "s": "š", "u": "ų", "z": "ž"]
        case .arabic: return ["ا": "أ", "ي": "ى", "و": "ؤ", "ه": "ة", "ء": "أ"]
        default: return [:]
        }
    }

    /// Mirrors `returnKey` in Keyboard/Strings.swift.
    private var returnTitle: String {
        switch shownLanguage {
        case .hungarian: return "Enter"
        case .spanish: return "intro"
        case .french: return "retour"
        case .german: return "Return"
        case .italian: return "invio"
        case .portuguese: return "retorno"
        case .russian: return "ввод"
        case .ukrainian: return "ввід"
        case .swedish: return "retur"
        case .lithuanian: return "grįžti"
        case .arabic: return "إدخال"
        default: return "return"
        }
    }

    private struct PreviewKey {
        var title = ""
        var symbol: String? = nil
        /// An emoji-picker tab icon (EmojiTabIcons) instead of an SF Symbol, as the keyboard's emoji key uses.
        var tabIcon: String? = nil
        var weight: CGFloat = 1
        var function = false
        var spacer = false
        var accent = false
        var active = false
        var space = false
    }

    /// Mirrors KeyboardViewController.reloadKeyboardLayout: the user's text, or the language's name or code.
    private var spaceTitle: String {
        let custom = spaceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return custom }
        return spaceLanguageCode ? shownLanguage.rawValue.uppercased() : shownLanguage.displayName
    }

    private var keyRows: [[PreviewKey]] {
        let letters = letterRows
        let top = letters[0].count
        let locale = Locale(identifier: shownLanguage.rawValue)
        func letterKey(_ l: String) -> PreviewKey { return PreviewKey(title: l.uppercased(with: locale)) }
        let side = CGFloat(max(0, top - letters[1].count)) / 2
        var row2: [PreviewKey] = []
        if side > 0 { row2.append(PreviewKey(weight: side, spacer: true)) }
        row2 += letters[1].map(letterKey)
        if side > 0 { row2.append(PreviewKey(weight: side, spacer: true)) }
        let edge = min(1.8, max(1.0, CGFloat(top - letters[2].count) / 2))
        // As the keyboard: no shift key for a language without capitals; delete takes its room.
        var row3 = shownLanguage.hasCapitals ? [PreviewKey(symbol: "shift.fill", weight: edge, function: true, accent: true)] : []
        row3 += letters[2].map(letterKey)
        row3.append(PreviewKey(symbol: "delete.left",
                               weight: shownLanguage.hasCapitals ? edge : max(1.5, CGFloat(top - letters[2].count)),
                               function: true))
        return [
            letters[0].map(letterKey),
            row2,
            row3,
            [PreviewKey(title: "123", weight: 1.3, function: true),
             PreviewKey(tabIcon: "smileys", function: true),
             PreviewKey(title: shownLanguage == .arabic ? "\u{060C}" : ","),
             PreviewKey(title: spaceTitle, weight: 3.9, space: true),
             PreviewKey(title: "."),
             PreviewKey(title: returnTitle, weight: 1.8, function: true, accent: true)]
        ]
    }

    // MARK: Palette (mirrors Keyboard/Theme.swift, in the iPhone's light or dark mode)

    private var dark: Bool { return systemScheme == .dark }
    /// Themes that sit on the normal system keyboard background.
    private var onSystemBackground: Bool { return theme.kind == .native || theme.kind == .colored }

    private func pick(_ light: Color, _ darkColor: Color) -> Color { return dark ? darkColor : light }

    /// Key-colour themes are a lighter shade in light mode (as on the keyboard).
    private var colors: ThemeDefinition { return dark ? theme : theme.lightModeVariant }

    /// Labels on the keys: the theme's own on key-colour themes, the system label colour on the others.
    private var textColor: Color { return theme.kind == .colored ? Color(colors.text) : pick(.black, .white) }
    /// Strip text sits on the background, not on a key.
    private var stripText: Color { return pick(Color(white: 0.08), .white) }

    private var keyFill: Color {
        switch theme.kind {
        case .native: return pick(.white, Color(white: 0.42))
        case .colored: return Color(colors.key)
        case .transparent: return pick(Color.white.opacity(0.34), Color.white.opacity(0.16))
        case .liquidGlass: return pick(Color.white, Color.white.opacity(0.16))
        }
    }

    private var functionFill: Color {
        switch theme.kind {
        case .native: return pick(Color(red: 0.675, green: 0.702, blue: 0.745), Color(white: 0.27))
        case .colored: return Color(colors.function)
        case .transparent: return pick(Color.black.opacity(0.12), Color.black.opacity(0.28))
        case .liquidGlass: return pick(Color.black.opacity(0.08), Color.white.opacity(0.10))
        }
    }

    private var borderColor: Color {
        switch theme.kind {
        case .native: return .clear
        case .liquidGlass: return pick(Color.white.opacity(0.60), Color.white.opacity(0.25))
        default: return pick(Color.white.opacity(0.60), Color.white.opacity(0.28))
        }
    }

    /// Key-colour themes keep their own accent until the user picks one (as on the keyboard).
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    private var usesThemeAccent: Bool {
        return theme.kind == .colored && accentHex.isEmpty && accentName == SettingDefault.accent
    }
    private var accentColor: Color { return usesThemeAccent ? Color(theme.accent) : accent }
    private var onAccent: Color { return usesThemeAccent ? Color(theme.onAccent) : .white }

    @ViewBuilder private var backdrop: some View {
        if onSystemBackground {
            Rectangle().fill(pick(Color(red: 0.82, green: 0.84, blue: 0.86), Color(white: 0.17)))
        } else if theme.kind == .transparent {
            // The keyboard's frosted panel over the app (Theme.panelBackground).
            Rectangle().fill(pick(Color(white: 0.93), Color(white: 0.12)))
        } else {
            // Liquid Glass has no panel: the app shows straight through. A colourful backdrop stands in for the
            // app, so the glass keys have something to bend and blur.
            ZStack {
                LinearGradient(colors: pick([Color(red: 0.62, green: 0.80, blue: 1.0), Color(red: 1.0, green: 0.80, blue: 0.86)],
                                            [Color(red: 0.10, green: 0.16, blue: 0.38), Color(red: 0.36, green: 0.12, blue: 0.34)]),
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                GeometryReader { geometry in
                    Circle()
                        .fill(pick(Color(red: 1.0, green: 0.86, blue: 0.45), Color(red: 0.95, green: 0.45, blue: 0.30)).opacity(0.75))
                        .frame(width: geometry.size.width * 0.45)
                        .blur(radius: geometry.size.width * 0.06)
                        .offset(x: geometry.size.width * 0.55, y: -geometry.size.width * 0.08)
                    Circle()
                        .fill(pick(Color(red: 0.45, green: 0.85, blue: 0.75), Color(red: 0.20, green: 0.55, blue: 0.70)).opacity(0.7))
                        .frame(width: geometry.size.width * 0.38)
                        .blur(radius: geometry.size.width * 0.05)
                        .offset(x: -geometry.size.width * 0.06, y: geometry.size.height * 0.45)
                }
            }
        }
    }

    private func pick(_ light: [Color], _ darkColors: [Color]) -> [Color] { return dark ? darkColors : light }

    // MARK: Body

    /// The real keyboard's size in points (Keyboard/KeyboardViewController.applyHeight): 440 wide, the strip over
    /// four rows of keys (key height + row gap) and 8pt of padding; 276pt at the defaults. Callers use these
    /// ratios so the preview has the keyboard's proportions.
    /// (Read straight from the defaults: the Settings snapshot can lag a moment behind the app's own controls.)
    static var aspectWithStrip: CGFloat {
        return 440 / (CGFloat(stored(SettingKey.suggestionHeight)) + keysHeight)
    }
    static var aspectKeysOnly: CGFloat { return 440 / keysHeight }

    private static var keysHeight: CGFloat {
        return CGFloat(8 + 4 * (stored(SettingKey.keyHeight) + stored(SettingKey.rowGap)))
    }

    private static func stored(_ key: String) -> Double {
        return SharedStore.defaults.double(forKey: key)   // registered defaults fill in unset values
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            // Everything is measured in the keyboard's points and scaled to the preview's width.
            let s = width / 440
            let stripHeight = showsStrip ? CGFloat(suggestionHeight) * s : 0
            let verticalPadding = 4 * s
            let rowHeight = max(1, (height - stripHeight - verticalPadding * 2) / 4)
            let keyHeight = max(1, rowHeight - CGFloat(rowGap) * s)
            // A narrower keyboard (the Width setting) is centred.
            let rowWidth = (width - 2 * s) * CGFloat(keyboardWidth)

            ZStack(alignment: .top) {
                backdrop
                VStack(spacing: 0) {
                    if showsStrip { strip(height: stripHeight, scale: s) }
                    VStack(spacing: 0) {
                        ForEach(0..<keyRows.count, id: \.self) { index in
                            row(keyRows[index], rowWidth: rowWidth, rowHeight: rowHeight, keyHeight: keyHeight, scale: s)
                        }
                    }
                    .padding(.vertical, verticalPadding)
                }
            }
            .frame(width: width, height: height)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Pieces

    /// A row as KeyboardView lays it out: each key's touch cell is its share of the width by weight, and the
    /// key is drawn half the key gap in from each side of its cell and half the row gap from the top and bottom.
    private func row(_ keys: [PreviewKey], rowWidth: CGFloat, rowHeight: CGFloat, keyHeight: CGFloat,
                     scale s: CGFloat) -> some View {
        let total = keys.reduce(CGFloat(0)) { $0 + $1.weight }
        let unit = rowWidth / max(total, 1)
        return HStack(spacing: 0) {
            ForEach(0..<keys.count, id: \.self) { i in
                let k = keys[i]
                let cell = unit * k.weight
                Group {
                    if k.spacer {
                        Color.clear
                    } else {
                        key(k, width: max(1, cell - CGFloat(keyGap) * s), height: keyHeight, scale: s)
                    }
                }
                .frame(width: cell, height: rowHeight)
            }
        }
        .frame(width: rowWidth)
    }

    /// The suggestion strip: three slots with dividers (or on segments, as the Suggestions screen sets it) and
    /// the accent-coloured hide-keyboard button. Mirrors Keyboard/SuggestionBar.swift.
    private func strip(height: CGFloat, scale s: CGFloat) -> some View {
        let words = shownLanguage == .hungarian ? ["A", "Én", "Nem"] : ["I", "The", "It"]
        let segments = suggestionStyle == "segments"
        let radius = CGFloat(min(1, max(0, roundness))) * (height - 13 * s) / 2
        // The word space would write sits on the accent pill (SuggestionBar.bestPill), hugging it with the keys'
        // corner style; on segments the whole middle segment takes the accent.
        let pillHeight = max(1, height - 18 * s)
        let pillRadius = min(pillHeight / 2, CGFloat(min(1, max(0, roundness))) * pillHeight / 2 * 1.6)
        return HStack(spacing: 0) {
            ForEach(0..<words.count, id: \.self) { i in
                let best = i == 1
                Text(words[i])
                    .font(.system(size: 17 * s, weight: best ? .semibold : .regular))
                    .foregroundColor(best ? onAccent : (segments && followTheme ? textColor : stripText))
                    .lineLimit(1)
                    .padding(.horizontal, best && !segments ? 14 * s : 0)
                    .frame(minWidth: best && !segments ? pillHeight * 1.6 : 0)
                    .frame(height: best && !segments ? pillHeight : nil)
                    .background {
                        if best && !segments { bestPill(radius: pillRadius) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        if segments {
                            Group {
                                if best {
                                    bestPill(radius: radius)
                                } else {
                                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                                        .fill(followTheme ? keyFill : pick(Color.black.opacity(0.06), Color.white.opacity(0.12)))
                                }
                            }
                            .padding(.horizontal, 2.5 * s)
                            .padding(.vertical, 3 * s)
                        }
                    }
                    .overlay(alignment: .trailing) {
                        if i < words.count - 1 && !segments && separatorStyle != "none" {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: max(1, s), height: height * 0.5)
                                .overlay(
                                    Path { path in
                                        path.move(to: CGPoint(x: 0.5, y: 0))
                                        path.addLine(to: CGPoint(x: 0.5, y: height * 0.5))
                                    }
                                    .stroke(stripSeparator,
                                            style: StrokeStyle(lineWidth: separatorStyle == "dotted" ? 1.5 * s : max(0.5, s),
                                                               lineCap: separatorStyle == "dotted" ? .round : .butt,
                                                               dash: separatorDash(scale: s))))
                        }
                    }
            }
            Image(systemName: "keyboard.chevron.compact.down")
                .font(.system(size: 15 * s))
                .foregroundColor(accentColor)
                .frame(width: 52 * s)
        }
        .padding(.leading, 8 * s)
        .padding(.top, 9 * s)
        .padding(.bottom, 1.5 * s)
        .frame(height: height)
    }

    private var separatorColor: Color { return pick(Color.black.opacity(0.12), Color.white.opacity(0.20)) }

    /// The auto-correction pill: the accent colour, or accent-tinted glass in the Liquid Glass theme.
    @ViewBuilder private func bestPill(radius: CGFloat) -> some View {
        if theme.kind == .liquidGlass {
            GlassKeyShape(radius: radius, tint: accentColor, dark: dark)
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(accentColor)
        }
    }

    /// "Follow theme": a faded version of the key labels, else the neutral hairline.
    private var stripSeparator: Color { return followTheme ? textColor.opacity(0.35) : separatorColor }

    private func separatorDash(scale s: CGFloat) -> [CGFloat] {
        switch separatorStyle {
        case "dashed": return [4 * s, 3 * s]
        case "dotted": return [0.1, 3 * s]
        default: return []
        }
    }

    private var keyShadow: Color {
        return theme.kind == .native ? pick(Color(red: 0.53, green: 0.55, blue: 0.58), Color.black.opacity(0.55)) : .clear
    }

    private func key(_ k: PreviewKey, width: CGFloat, height: CGFloat, scale s: CGFloat) -> some View {
        // Theme.keyCornerRadius: the roundness share of half the key's shorter side.
        let radius = CGFloat(min(1, max(0, roundness))) * min(width, height) / 2
        let fill = k.accent ? accentColor : (k.function ? functionFill : keyFill)
        let tint: Color = k.accent ? onAccent : textColor
        let hint = keyHints && k.title.count == 1 ? hints[k.title.lowercased()] : nil
        let hintScale = CGFloat(hintSize)
        return ZStack {
            if theme.kind == .liquidGlass {
                // As the keyboard draws it: a piece of Liquid Glass, tinted for function keys and the accent.
                GlassKeyShape(radius: radius,
                              tint: k.accent ? accentColor : (k.function ? Color.black.opacity(dark ? 0.0 : 0.06) : nil),
                              dark: dark)
            } else {
                // As KeyView draws it: the fill, the sheen, the outline, and the glow or shadow under it.
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                let shadow = keyShadowStyle
                shape
                    .fill(fill)
                    .overlay {
                        if surface != "flat" {
                            shape.fill(LinearGradient(stops: [.init(color: Color.white.opacity(dark ? 0.12 : 0.22), location: 0),
                                                              .init(color: Color.white.opacity(0), location: 0.55),
                                                              .init(color: Color.black.opacity(dark ? 0.16 : 0.08), location: 1)],
                                                      startPoint: .top, endPoint: .bottom))
                        }
                    }
                    .overlay(shape.strokeBorder(keyOutline, lineWidth: keyOutlineWidth * max(s, 0.6)))
                    .shadow(color: shadow.color, radius: shadow.radius * s, x: 0, y: shadow.y * s)
            }
            if let tabIcon = k.tabIcon, let image = EmojiTabIcons.icon(forKey: tabIcon, side: 36, weight: 1.8) {
                // Same size and line weight as KeyView's emoji key, scaled with the preview.
                Image(uiImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 36 * s, height: 36 * s)
                    .foregroundColor(tint)
            } else if let symbol = k.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 20 * s))
                    .foregroundColor(tint)
            } else if !k.title.isEmpty {
                Text(k.title)
                    .font(k.space ? .system(size: CGFloat(spaceTextSize) * s)
                          : (k.title.count == 1 ? .system(size: 23 * s * CGFloat(letterSize), weight: .light) : .system(size: 16 * s)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundColor(tint)
                    .padding(.horizontal, 2 * s)
            }
            if let hint = hint {
                // Where KeyView.layoutHint puts it.
                Text(hint)
                    .font(.system(size: (radius > 12 * s ? 9 : 10) * s * hintScale))
                    .foregroundColor(textColor.opacity(0.55))
                    .padding(.horizontal, 4 * s + radius * 0.3)
                    .padding(.vertical, 2 * s)
                    .frame(width: width, height: height, alignment: hintAlignment)
            }
        }
        .frame(width: width, height: height)
    }

    private var hintAlignment: Alignment {
        switch hintPosition {
        case "topLeft": return .topLeading
        case "topCenter": return .top
        case "bottomRight": return .bottomTrailing
        case "bottomCenter": return .bottom
        case "bottomLeft": return .bottomLeading
        default: return .topTrailing
        }
    }

    // MARK: Key style (mirrors Theme.keySurface / keyBorderStyle / keyGlow)

    /// "flat", "sheen" or "raised"; "auto": raised on the colour themes.
    private var surface: String {
        if keySurface != "auto" { return keySurface }
        return theme.kind == .colored ? "raised" : "flat"
    }

    private var borderStyle: String {
        if theme.kind == .liquidGlass {
            if #available(iOS 26, *) { return "none" }   // real glass keys have no outline
        }
        if keyBorderStyle != "auto" { return keyBorderStyle }
        return theme.kind == .native ? "none" : "thin"
    }

    private var keyOutlineWidth: CGFloat {
        switch borderStyle {
        case "thin": return 0.5
        case "bold": return 1.5
        case "accent": return 1.2
        default: return 0
        }
    }

    private var keyOutline: Color {
        switch borderStyle {
        case "thin": return theme.kind == .native ? pick(Color.black.opacity(0.18), Color.white.opacity(0.28)) : borderColor
        case "bold": return textColor.opacity(0.4)
        case "accent": return accentColor
        default: return .clear
        }
    }

    /// The accent glow, the raised key's drop shadow, or the native key's 1pt line.
    private var keyShadowStyle: (color: Color, radius: CGFloat, y: CGFloat) {
        switch keyGlow {
        case "soft": return (accentColor.opacity(0.55), 5, 0)
        case "strong": return (accentColor.opacity(0.95), 10, 0)
        default: break
        }
        if surface == "raised" { return (Color.black.opacity(dark ? 0.45 : 0.25), 1.5, 1.5) }
        return (keyShadow, 0, 1)
    }
}

/// A key of the Liquid Glass theme: real Liquid Glass on iOS 26 and later; before that a frosted pane with the
/// glass's bright rim and sheen, as the keyboard's fallback blur looks.
private struct GlassKeyShape: View {
    let radius: CGFloat
    let tint: Color?
    let dark: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(tint.map { Glass.regular.tint($0) } ?? .regular, in: shape)
        } else {
            fallback(shape)
        }
        #else
        fallback(shape)
        #endif
    }

    private func fallback(_ shape: RoundedRectangle) -> some View {
        shape
            .fill(.ultraThinMaterial)
            .overlay(shape.fill(tint ?? Color.clear).opacity(0.55))
            .overlay(shape.fill(LinearGradient(colors: [Color.white.opacity(dark ? 0.18 : 0.45), Color.white.opacity(0)],
                                               startPoint: .top, endPoint: .center)))
            .overlay(shape.strokeBorder(Color.white.opacity(dark ? 0.35 : 0.8), lineWidth: 0.8))
            .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
    }
}
