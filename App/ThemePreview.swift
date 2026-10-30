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
    @AppStorage(SettingKey.keyBorders, store: SharedStore.defaults) private var keyBorders = SettingDefault.keyBorders
    @AppStorage(SettingKey.keyHints, store: SharedStore.defaults) private var keyHints = SettingDefault.keyHints

    @Environment(\.colorScheme) private var systemScheme

    /// The language whose layout is drawn; defaults to the first enabled language, like the keyboard.
    var language: Language? = nil

    private var shownLanguage: Language {
        if let language = language { return language }
        let enabled = Language.list(from: Settings.shared.enabledLanguages)
        if let current = Language(rawValue: Settings.shared.languageCode), enabled.contains(current) { return current }
        return enabled.first ?? .english
    }

    // Mirrors `Language.letterRows` / `accents` in Keyboard/Layouts.swift (keyboard-only code, so copied here).
    private var letterRows: [[String]] {
        func split(_ rows: String...) -> [[String]] { return rows.map { $0.map { String($0) } } }
        switch shownLanguage {
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
        var row3 = [PreviewKey(symbol: "shift.fill", weight: edge, function: true, accent: true)]
        row3 += letters[2].map(letterKey)
        row3.append(PreviewKey(symbol: "delete.left", weight: edge, function: true))
        return [
            letters[0].map(letterKey),
            row2,
            row3,
            [PreviewKey(title: "123", weight: 1.3, function: true),
             PreviewKey(tabIcon: "smileys", function: true),
             PreviewKey(title: ","),
             PreviewKey(title: shownLanguage.displayName, weight: 3.9),
             PreviewKey(title: "."),
             PreviewKey(title: returnTitle, weight: 1.8, function: true, accent: true)]
        ]
    }

    // MARK: Palette (mirrors Keyboard/Theme.swift, in the iPhone's light or dark mode)

    private var dark: Bool { return systemScheme == .dark }
    /// Themes that sit on the normal system keyboard background.
    private var onSystemBackground: Bool { return theme.kind == .native || theme.kind == .colored }

    private func pick(_ light: Color, _ darkColor: Color) -> Color { return dark ? darkColor : light }

    /// Labels on the keys: the theme's own on key-colour themes, the system label colour on the others.
    private var textColor: Color { return theme.kind == .colored ? Color(theme.text) : pick(.black, .white) }
    /// Strip text sits on the background, not on a key.
    private var stripText: Color { return pick(Color(white: 0.08), .white) }

    private var keyFill: Color {
        switch theme.kind {
        case .native: return pick(.white, Color(white: 0.42))
        case .colored: return Color(theme.key)
        case .transparent: return pick(Color.white.opacity(0.34), Color.white.opacity(0.16))
        case .liquidGlass: return pick(Color.white, Color.white.opacity(0.16))
        }
    }

    private var functionFill: Color {
        switch theme.kind {
        case .native: return pick(Color(red: 0.675, green: 0.702, blue: 0.745), Color(white: 0.27))
        case .colored: return Color(theme.function)
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
            // Liquid Glass has no panel: the app shows straight through.
            Rectangle().fill(pick(Color(white: 0.97), Color(white: 0.05)))
        }
    }

    // MARK: Body

    /// The real keyboard's size in points (Keyboard/KeyboardViewController.applyHeight): 440 wide, a 44pt strip
    /// over 232pt of keys. Callers use these ratios so the preview has the keyboard's proportions.
    static let aspectWithStrip: CGFloat = 440 / 276
    static let aspectKeysOnly: CGFloat = 440 / 232

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            // Everything is measured in the keyboard's points and scaled to the preview's width.
            let s = width / 440
            let stripHeight = showsStrip ? 44 * s : 0
            let verticalPadding = 4 * s
            let rowHeight = max(1, (height - stripHeight - verticalPadding * 2) / 4)
            let keyHeight = max(1, rowHeight - 11 * s)
            let rowWidth = width - 2 * s

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
    /// key is drawn 3pt in from each side of its cell and 5.5pt from the top and bottom.
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
                        key(k, width: max(1, cell - 6 * s), height: keyHeight, scale: s)
                    }
                }
                .frame(width: cell, height: rowHeight)
            }
        }
        .frame(width: rowWidth)
    }

    /// The suggestion strip: three slots with thin dividers and the accent-coloured hide-keyboard button.
    private func strip(height: CGFloat, scale s: CGFloat) -> some View {
        let words = shownLanguage == .hungarian ? ["A", "Én", "Nem"] : ["I", "The", "It"]
        return HStack(spacing: 0) {
            ForEach(0..<words.count, id: \.self) { i in
                Text(words[i])
                    .font(.system(size: 17 * s))
                    .foregroundColor(stripText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .trailing) {
                        if i < words.count - 1 {
                            Rectangle().fill(separatorColor).frame(width: max(0.5, s), height: height * 0.5)
                        }
                    }
            }
            Image(systemName: "keyboard.chevron.compact.down")
                .font(.system(size: 18 * s))
                .foregroundColor(accentColor)
                .frame(width: 52 * s)
        }
        .padding(.leading, 8 * s)
        .padding(.top, 9 * s)
        .frame(height: height)
    }

    private var separatorColor: Color { return pick(Color.black.opacity(0.12), Color.white.opacity(0.20)) }

    private var keyShadow: Color {
        return theme.kind == .native ? pick(Color(red: 0.53, green: 0.55, blue: 0.58), Color.black.opacity(0.55)) : .clear
    }

    private func key(_ k: PreviewKey, width: CGFloat, height: CGFloat, scale s: CGFloat) -> some View {
        // Theme.keyCornerRadius: the roundness share of half the key's shorter side.
        let radius = CGFloat(min(1, max(0, roundness))) * min(width, height) / 2
        let fill = k.accent ? accentColor : (k.function ? functionFill : keyFill)
        let tint: Color = k.accent ? onAccent : textColor
        let hint = keyHints && k.title.count == 1 ? hints[k.title.lowercased()] : nil
        return ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
                .shadow(color: keyShadow, radius: 0, x: 0, y: s)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(borderColor, lineWidth: drawsBorder ? 0.5 : 0))
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
                    .font(k.title.count == 1 ? .system(size: 23 * s, weight: .light) : .system(size: 16 * s))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundColor(tint)
                    .padding(.horizontal, 2 * s)
            }
            if let hint = hint {
                Text(hint)
                    .font(.system(size: (radius > 12 * s ? 9 : 10) * s))
                    .foregroundColor(textColor.opacity(0.55))
                    .padding(.trailing, 4 * s + radius * 0.3)
                    .padding(.top, 2 * s)
                    .frame(width: width, height: height, alignment: .topTrailing)
            }
        }
        .frame(width: width, height: height)
    }

    /// Outlines: every theme but Native (and real Liquid Glass) when Key borders is on.
    private var drawsBorder: Bool {
        guard keyBorders, theme.kind != .native else { return false }
        if theme.kind == .liquidGlass {
            if #available(iOS 26, *) { return false }
        }
        return true
    }
}
