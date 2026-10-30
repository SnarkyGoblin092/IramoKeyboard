import SwiftUI

/// A miniature keyboard drawn from a `ThemeDefinition`, so the picker shows what the keyboard will look like.
/// Every theme uses the same translucent look (thin border, soft fills); only the colours differ.
struct ThemePreview: View {
    let theme: ThemeDefinition
    let accent: Color
    var showsStrip = true
    var cornerRadius: CGFloat = 14
    @AppStorage(SettingKey.keyRoundness, store: SharedStore.defaults) private var roundness = SettingDefault.keyRoundness
    @AppStorage(SettingKey.keyBorders, store: SharedStore.defaults) private var keyBorders = SettingDefault.keyBorders

    @Environment(\.colorScheme) private var systemScheme

    /// The language whose layout is drawn; defaults to the first enabled language, like the keyboard.
    var language: Language? = nil

    private var shownLanguage: Language {
        if let language = language { return language }
        return Language.list(from: Settings.shared.enabledLanguages).first ?? .english
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
        var weight: CGFloat = 1
        var function = false
        var spacer = false
        var accent = false
        var active = false
    }

    private var keyRows: [[PreviewKey]] {
        let letters = letterRows
        let top = letters[0].count
        func letterKey(_ l: String) -> PreviewKey { return PreviewKey(title: l) }
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
             PreviewKey(symbol: "face.smiling", function: true),
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
        case .liquidGlass: return pick(Color.white.opacity(0.22), Color.white.opacity(0.10))
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
        } else if theme.gradientStops.count > 1 {
            // A stand-in for what shows through the clear keyboard, darker in dark mode.
            LinearGradient(colors: theme.gradientStops.map { Color($0) },
                           startPoint: UnitPoint(x: theme.gradientStart.x, y: theme.gradientStart.y),
                           endPoint: UnitPoint(x: theme.gradientEnd.x, y: theme.gradientEnd.y))
                .overlay(Color.black.opacity(dark ? 0.55 : 0))
        } else {
            Rectangle().fill(pick(Color(white: 0.6), Color(white: 0.2)))
        }
    }

    // MARK: Body

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let gap = max(1.5, width * 0.012)
            let sidePad = gap * 1.5
            let stripHeight = showsStrip ? height * 0.14 : 0
            let rowCount: CGFloat = 4
            let keyHeight = max(1, (height - stripHeight - gap * (rowCount + 1) - (showsStrip ? gap : 0)) / rowCount)
            let rowWidth = width - sidePad * 2
            let unit = max(1, (rowWidth - gap * 9) / 10)
            let radius = max(0, roundness * min(unit, keyHeight) / 2)

            ZStack {
                backdrop
                VStack(spacing: gap) {
                    if showsStrip { strip(height: stripHeight) }
                    ForEach(0..<keyRows.count, id: \.self) { index in
                        row(keyRows[index], rowWidth: rowWidth, gap: gap, height: keyHeight, radius: radius,
                            hintsOn: showsStrip)
                    }
                }
                .padding(.horizontal, sidePad)
                .padding(.vertical, gap)
            }
            .frame(width: width, height: height)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Pieces

    /// A row scaled to the full width by key weights, like the real keyboard.
    private func row(_ keys: [PreviewKey], rowWidth: CGFloat, gap: CGFloat, height: CGFloat,
                     radius: CGFloat, hintsOn: Bool) -> some View {
        let total = keys.reduce(CGFloat(0)) { $0 + $1.weight }
        let usable = rowWidth - gap * CGFloat(keys.count - 1)
        return HStack(spacing: gap) {
            ForEach(0..<keys.count, id: \.self) { i in
                let k = keys[i]
                let w = max(1, usable * k.weight / total)
                if k.spacer {
                    Color.clear.frame(width: w, height: height)
                } else {
                    key(k, width: w, height: height, radius: radius, hint: hintsOn ? hints[k.title] : nil)
                }
            }
        }
    }

    /// Flat strip: no border, three slots with thin dividers and the hide-keyboard slot.
    private func strip(height: CGFloat) -> some View {
        let words = ["the", "that", "this"]
        let size = max(6, height * 0.42)
        return HStack(spacing: 0) {
            ForEach(0..<words.count, id: \.self) { i in
                Text(words[i])
                    .font(.system(size: size))
                    .foregroundColor(stripText)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        Rectangle().fill(separatorColor).frame(width: 0.5).padding(.vertical, height * 0.22),
                        alignment: .trailing)
            }
            Image(systemName: "keyboard.chevron.compact.down")
                .font(.system(size: size))
                .foregroundColor(stripText.opacity(0.6))
                .frame(width: height * 1.4)
        }
        .frame(height: height)
    }

    private var separatorColor: Color { return stripText.opacity(0.2) }

    private func key(_ k: PreviewKey, width: CGFloat, height: CGFloat, radius: CGFloat, hint: String?) -> some View {
        let fill = k.accent ? accentColor : (k.function ? functionFill : keyFill)
        let tint: Color = k.accent ? onAccent : (k.active ? accentColor : textColor)
        return ZStack {
            shape(radius, fill: fill)
            if let symbol = k.symbol {
                Image(systemName: symbol)
                    .font(.system(size: max(5, height * 0.38)))
                    .foregroundColor(tint)
            } else if !k.title.isEmpty {
                Text(k.title)
                    .font(.system(size: max(6, height * (k.title.count > 2 ? 0.3 : 0.5))))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundColor(tint)
                    .padding(.horizontal, 2)
            }
            if let hint = hint {
                Text(hint)
                    .font(.system(size: max(4, height * 0.2)))
                    .foregroundColor(textColor.opacity(0.55))
                    .padding(.trailing, 2 + radius * 0.3)
                    .padding(.top, 1)
                    .frame(width: width, height: height, alignment: .topTrailing)
            }
        }
        .frame(width: width, height: height)
    }

    private func shape(_ radius: CGFloat, fill: Color) -> some View {
        let rounded = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return rounded
            .fill(fill)
            .overlay(rounded.stroke(borderColor, lineWidth: keyBorders ? 0.5 : 0))
    }
}
