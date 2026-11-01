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
    // What the keyboard shows when it opens: the number row, shift on at the start of a sentence (with
    // auto-capitalization) or capitals always, and the key font.
    @AppStorage(SettingKey.numberRow, store: SharedStore.defaults) private var numberRow = SettingDefault.numberRow
    @AppStorage(SettingKey.autoCapitalize, store: SharedStore.defaults) private var autoCapitalize = SettingDefault.autoCapitalize
    @AppStorage(SettingKey.alwaysCapitals, store: SharedStore.defaults) private var alwaysCapitals = SettingDefault.alwaysCapitals
    @AppStorage(SettingKey.keyFont, store: SharedStore.defaults) private var keyFontID = SettingDefault.keyFont

    @Environment(\.colorScheme) private var systemScheme

    /// The language whose layout is drawn; defaults to the first enabled language, like the keyboard.
    var language: Language? = nil

    private var shownLanguage: Language { return language ?? ThemePreview.openingLanguage }

    /// The language the keyboard opens in: the current one, if it is enabled.
    static var openingLanguage: Language {
        let enabled = Language.list(from: Settings.shared.enabledLanguages)
        if let current = Language(rawValue: Settings.shared.languageCode), enabled.contains(current) { return current }
        return enabled.first ?? .english
    }

    /// Rows of letters beyond the usual three (Thai has four), which make the keyboard taller.
    static var extraLetterRows: Int { return max(0, letterRows(for: openingLanguage).count - 3) }

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
        case .lithuanian, .cantonese: return split("qwertyuiop", "asdfghjkl", "zxcvbnm")
        case .arabic: return split("ضصثقفغعهخحجد", "شسيبلاتنمكط", "ذئءؤرىةوزظ")
        case .japanese: return split("qwertyuiop", "asdfghjkl", "zxcvbnm")
        case .korean: return split("ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔ", "ㅁㄴㅇㄹㅎㅗㅓㅏㅣ", "ㅋㅌㅊㅍㅠㅜㅡ")
        case .hindi: return split("ौैाीूबहगदजड", "ोे्िुपरकतचट", "ंमनवलसयश")
        case .thai: return split("ภถุึคตจขช", "ๆไำพะัีรนยบล", "ฟหกดเ้่าสวง", "ผปแอิืทมใฝ")
        case .danish: return split("qwertyuiopå", "asdfghjklæø", "zxcvbnm")
        case .norwegian: return split("qwertyuiopå", "asdfghjkløæ", "zxcvbnm")
        case .finnish: return split("qwertyuiopå", "asdfghjklöä", "zxcvbnm")
        case .greek: return split("ςερτυθιοπ", "ασδφγηξκλ", "ζχψωβνμ")
        case .hebrew: return split("קראטוןםפ", "שדגכעיחלךף", "זסבהנמצתץ")
        case .persian: return split("ضصثقفغعهخحجچ", "شسیبلاتنمکگ", "ظطژزرذدپو")
        case .indonesian: return split("qwertyuiop", "asdfghjkl", "zxcvbnm")
        case .malay: return split("qwertyuiop", "asdfghjkl", "zxcvbnm")
        case .vietnamese: return split("qwertyuiop", "asdfghjkl", "zxcvbnm")
        case .slovak: return split("qwertzuiop", "asdfghjkl", "yxcvbnm")
        case .croatian: return split("qwertzuiopšđ", "asdfghjklčćž", "yxcvbnm")
        case .bulgarian: return split("явертъуиопчш", "асдфгхйклщ", "зьцжбнмю")
        case .catalan: return split("qwertyuiop", "asdfghjklç", "zxcvbnm")
        case .mandarin: return split("qwertyuiop", "asdfghjkl", "zxcvbnm")
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
        case .korean: return ["ㅂ": "ㅃ", "ㅈ": "ㅉ", "ㄷ": "ㄸ", "ㄱ": "ㄲ", "ㅅ": "ㅆ", "ㅐ": "ㅒ", "ㅔ": "ㅖ"]
        case .hindi: return ["ा": "आ", "ि": "इ", "ी": "ई", "ु": "उ", "ू": "ऊ", "े": "ए", "ै": "ऐ", "ो": "ओ", "ौ": "औ", "्": "अ", "ं": "ँ", "क": "ख", "ग": "घ", "ज": "झ", "त": "थ", "द": "ध", "ट": "ठ", "ड": "ढ", "प": "फ", "ब": "भ", "च": "छ", "न": "ण", "स": "ष", "श": "क्ष", "ल": "ळ", "य": "य़"]
        case .thai: return ["เ": "โ", "ส": "ศ", "ท": "ธ", "น": "ณ", "ย": "ญ", "ด": "ฎ", "ต": "ฏ", "ถ": "ฐ", "ล": "ฬ", "ร": "ฤ", "ห": "ฮ", "่": "๋", "้": "๊", "ข": "ฃ", "ค": "ฅ", "ช": "ฉ", "พ": "ฑ", "ะ": "ฯ", "ั": "ํ", "ุ": "ู", "ี": "ื"]
        case .danish: return ["e": "é", "o": "ö", "a": "ä"]
        case .norwegian: return ["e": "é", "o": "ó"]
        case .finnish: return ["s": "š", "z": "ž"]
        case .greek: return ["α": "ά", "ε": "έ", "η": "ή", "ι": "ί", "ο": "ό", "υ": "ύ", "ω": "ώ"]
        case .persian: return ["ا": "آ", "ی": "ئ", "و": "ؤ", "ه": "ة", "ک": "ك"]
        case .indonesian: return ["e": "é"]
        case .vietnamese: return ["a": "á", "e": "é", "i": "í", "o": "ó", "u": "ú", "y": "ý", "d": "đ"]
        case .slovak: return ["a": "á", "c": "č", "d": "ď", "e": "é", "i": "í", "l": "ľ", "n": "ň", "o": "ó", "r": "ŕ", "s": "š", "t": "ť", "u": "ú", "y": "ý", "z": "ž"]
        case .bulgarian: return ["и": "ѝ"]
        case .catalan: return ["a": "à", "e": "è", "i": "í", "o": "ò", "u": "ú", "l": "·"]
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
        case .cantonese: return "換行"
        case .danish: return "retur"
        case .norwegian: return "retur"
        case .finnish: return "rivinvaihto"
        case .greek: return "εισαγωγή"
        case .hebrew: return "חזרה"
        case .persian: return "ورود"
        case .indonesian: return "enter"
        case .malay: return "kembali"
        case .vietnamese: return "xuống dòng"
        case .slovak: return "enter"
        case .croatian: return "povrat"
        case .bulgarian: return "нов ред"
        case .catalan: return "retorn"
        case .mandarin: return "换行"
        case .japanese: return "改行"
        case .korean: return "줄바꿈"
        case .hindi: return "एंटर"
        case .thai: return "ขึ้นบรรทัด"
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
        let last = letters[letters.count - 1]
        let top = letters.dropLast().map { $0.count }.max() ?? last.count
        let locale = Locale(identifier: shownLanguage.rawValue)
        // As the keyboard opens in an empty field: shift on (capitals) with auto-capitalization.
        let shiftOn = autoCapitalize && shownLanguage.hasCapitals
        let capitals = (shiftOn || alwaysCapitals) && shownLanguage.hasCapitals
        func letterKey(_ l: String) -> PreviewKey { return PreviewKey(title: capitals ? l.uppercased(with: locale) : l) }
        // Every row but the last centred under the longest (Thai has four rows of letters).
        let upper: [[PreviewKey]] = letters.dropLast().map { (letterRow: [String]) -> [PreviewKey] in
            let side = CGFloat(max(0, top - letterRow.count)) / 2
            var row: [PreviewKey] = []
            if side > 0 { row.append(PreviewKey(weight: side, spacer: true)) }
            row += letterRow.map(letterKey)
            if side > 0 { row.append(PreviewKey(weight: side, spacer: true)) }
            return row
        }
        let edge = min(1.8, max(1.0, CGFloat(top - last.count) / 2))
        // As the keyboard: no shift key for a language without capitals; delete takes its room.
        var row3 = shownLanguage.hasCapitals
            ? [PreviewKey(symbol: shiftOn ? "shift.fill" : "shift", weight: edge, function: true, accent: shiftOn)] : []
        row3 += last.map(letterKey)
        row3.append(PreviewKey(symbol: "delete.left",
                               weight: shownLanguage.hasCapitals ? edge : max(1.5, CGFloat(top - last.count)),
                               function: true))
        var rows: [[PreviewKey]] = []
        if numberRow {
            rows.append(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map { PreviewKey(title: $0) })
        }
        return rows + upper + [
            row3,
            [PreviewKey(title: "123", weight: 1.3, function: true),
             PreviewKey(tabIcon: "smileys", function: true),
             PreviewKey(title: shownLanguage.usesArabicPunctuation ? "\u{060C}"
                 : (shownLanguage == .japanese ? "\u{3001}" : (shownLanguage.usesPhoneticInput ? "\u{FF0C}" : ","))),
             PreviewKey(title: spaceTitle, weight: 3.9, space: true),
             PreviewKey(title: shownLanguage == .hindi ? "\u{0964}" : (shownLanguage.usesPhoneticInput ? "\u{3002}" : ".")),
             PreviewKey(title: returnTitle, weight: 1.8, function: true, accent: true)]
        ]
    }

    // MARK: Palette (ThemeLook, shared with the settings screens' previews)

    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent

    private var look: ThemeLook {
        return ThemeLook(theme: theme, accent: accent, dark: systemScheme == .dark, roundness: roundness,
                         keySurface: keySurface, keyBorderStyle: keyBorderStyle, keyGlow: keyGlow,
                         accentHex: accentHex, accentName: accentName)
    }

    private var dark: Bool { return look.dark }
    private func pick(_ light: Color, _ darkColor: Color) -> Color { return look.pick(light, darkColor) }
    private var textColor: Color { return look.textColor }
    private var stripText: Color { return look.stripText }
    private var keyFill: Color { return look.keyFill }
    private var accentColor: Color { return look.accentColor }
    private var onAccent: Color { return look.onAccent }
    private var backdrop: some View { return look.backdrop() }

    // MARK: Body

    /// The real keyboard's size in points (Keyboard/KeyboardViewController.applyHeight): 440 wide, the strip over
    /// four rows of keys (key height + row gap) and 8pt of padding; 276pt at the defaults. Callers use these
    /// ratios so the preview has the keyboard's proportions.
    /// (Read straight from the defaults: the Settings snapshot can lag a moment behind the app's own controls.)
    static var aspectWithStrip: CGFloat {
        return 440 / (CGFloat(stored(SettingKey.suggestionHeight)) + keysHeight)
    }
    static var aspectKeysOnly: CGFloat { return 440 / keysHeight }

    /// The rows of keys (the number row adds one) at the key height and row gap, and the padding.
    private static var keysHeight: CGFloat {
        let rows = (SharedStore.defaults.bool(forKey: SettingKey.numberRow) ? 5.0 : 4.0) + Double(extraLetterRows)
        return CGFloat(8 + rows * (stored(SettingKey.keyHeight) + stored(SettingKey.rowGap)))
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
            let rowHeight = max(1, (height - stripHeight - verticalPadding * 2) / CGFloat(max(keyRows.count, 1)))
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
                    // One glass container for all the keys, as the keyboard's (spacing 2pt).
                    .glassKeyGroup(theme.kind == .liquidGlass, spacing: 2 * s)
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
                    .font(keyFont(17 * s, weight: best ? .semibold : .regular))
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
    private func bestPill(radius: CGFloat) -> some View { return look.pill(radius: radius) }

    /// The keyboard's key font (KeyFont) at a size, as Theme.keyFont makes it.
    private func keyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return KeyFont.named(keyFontID).font(size: size, weight: weight)
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

    private func key(_ k: PreviewKey, width: CGFloat, height: CGFloat, scale s: CGFloat) -> some View {
        // Theme.keyCornerRadius: the roundness share of half the key's shorter side.
        let radius = CGFloat(min(1, max(0, roundness))) * min(width, height) / 2
        let tint: Color = k.accent ? onAccent : textColor
        let hint = keyHints && k.title.count == 1 ? hints[k.title.lowercased()] : nil
        let hintScale = CGFloat(hintSize)
        return ZStack {
            look.keyShape(k.accent ? .accent : (k.function ? .function : .letter), radius: radius, scale: s)
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
                    .font(k.space ? keyFont(CGFloat(spaceTextSize) * s)
                          : (k.title.count == 1 ? keyFont(23 * s * CGFloat(letterSize), weight: .light) : keyFont(16 * s)))
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

extension View {
    /// Liquid Glass keys share one glass container, as the keyboard's do (KeyboardView's `glassContainer`): glass
    /// that close together bends and reflects its neighbours, so the accent keys' colour shows in the keys around
    /// them. Without real glass (before iOS 26) the view is left as it is.
    @ViewBuilder func glassKeyGroup(_ enabled: Bool, spacing: CGFloat) -> some View {
        #if compiler(>=6.2)
        if enabled {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: spacing) { self }
            } else {
                self
            }
        } else {
            self
        }
        #else
        self
        #endif
    }
}

// MARK: - Theme look

/// How a theme draws, in light or dark mode, with the user's key style: the colours, the backdrop behind the keys
/// and a key's shape (fill, sheen, outline, glow or shadow; glass in the Liquid Glass theme). Mirrors
/// Keyboard/Theme.swift and KeyView; used by ThemePreview and the settings screens' previews.
struct ThemeLook {
    let theme: ThemeDefinition
    /// The user's accent (colour themes keep their own until one is picked).
    let accent: Color
    let dark: Bool
    var roundness: Double
    var keySurface: String
    var keyBorderStyle: String
    var keyGlow: String
    var accentHex: String
    var accentName: String

    enum KeyKind { case letter, function, accent }

    func pick(_ light: Color, _ darkColor: Color) -> Color { return dark ? darkColor : light }
    private func pick(_ light: [Color], _ darkColors: [Color]) -> [Color] { return dark ? darkColors : light }

    /// Themes that sit on the normal system keyboard background.
    var onSystemBackground: Bool { return theme.kind == .native || theme.kind == .colored }
    /// Key-colour themes are a lighter shade in light mode (as on the keyboard).
    private var colors: ThemeDefinition { return dark ? theme : theme.lightModeVariant }

    /// Labels on the keys: the theme's own on key-colour themes, the system label colour on the others.
    var textColor: Color { return theme.kind == .colored ? Color(colors.text) : pick(.black, .white) }
    /// Text on the background (the suggestion bar), not on a key.
    var stripText: Color { return pick(Color(white: 0.08), .white) }

    var keyFill: Color {
        switch theme.kind {
        case .native: return pick(.white, Color(white: 0.42))
        case .colored: return Color(colors.key)
        case .transparent: return pick(Color.white.opacity(0.34), Color.white.opacity(0.16))
        case .liquidGlass: return pick(Color.white, Color.white.opacity(0.16))
        }
    }

    var functionFill: Color {
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

    private var usesThemeAccent: Bool {
        return theme.kind == .colored && accentHex.isEmpty && accentName == SettingDefault.accent
    }
    var accentColor: Color { return usesThemeAccent ? Color(theme.accent) : accent }
    var onAccent: Color { return usesThemeAccent ? Color(theme.onAccent) : .white }

    /// Theme.keyCornerRadius: the roundness share of half the key's shorter side.
    func radius(width: CGFloat, height: CGFloat) -> CGFloat {
        return CGFloat(min(1, max(0, roundness))) * min(width, height) / 2
    }

    @ViewBuilder func backdrop() -> some View {
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

    /// A key as KeyView draws it: the fill, the sheen, the outline, and the glow or shadow under it; a piece of
    /// Liquid Glass (tinted for function keys and the accent) in that theme. `scale`: points of the preview per
    /// keyboard point.
    @ViewBuilder func keyShape(_ kind: KeyKind, radius: CGFloat, scale s: CGFloat = 1) -> some View {
        if theme.kind == .liquidGlass {
            // The keyboard's tints (KeyView.applyGlass, Theme's Liquid Glass palette).
            GlassKeyShape(radius: radius,
                          tint: kind == .accent ? accentColor.opacity(0.85)
                              : (kind == .function ? (dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)) : nil),
                          dark: dark)
        } else {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            let shadow = shadowStyle
            shape
                .fill(kind == .accent ? accentColor : (kind == .function ? functionFill : keyFill))
                .overlay {
                    if surface != "flat" {
                        shape.fill(LinearGradient(stops: [.init(color: Color.white.opacity(dark ? 0.12 : 0.22), location: 0),
                                                          .init(color: Color.white.opacity(0), location: 0.55),
                                                          .init(color: Color.black.opacity(dark ? 0.16 : 0.08), location: 1)],
                                                  startPoint: .top, endPoint: .bottom))
                    }
                }
                .overlay(shape.strokeBorder(outline, lineWidth: outlineWidth * max(s, 0.6)))
                .shadow(color: shadow.color, radius: shadow.radius * s, x: 0, y: shadow.y * s)
        }
    }

    /// The suggestion bar's accent pill (accent-tinted glass in the Liquid Glass theme).
    @ViewBuilder func pill(radius: CGFloat) -> some View {
        if theme.kind == .liquidGlass {
            GlassKeyShape(radius: radius, tint: accentColor, dark: dark)
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(accentColor)
        }
    }

    // MARK: Key style (mirrors Theme.keySurface / keyBorderStyle / keyGlow)

    /// "flat", "sheen" or "raised"; "auto": raised on the colour themes.
    var surface: String {
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

    private var outlineWidth: CGFloat {
        switch borderStyle {
        case "thin": return 0.5
        case "bold": return 1.5
        case "accent": return 1.2
        default: return 0
        }
    }

    private var outline: Color {
        switch borderStyle {
        case "thin": return theme.kind == .native ? pick(Color.black.opacity(0.18), Color.white.opacity(0.28)) : borderColor
        case "bold": return textColor.opacity(0.4)
        case "accent": return accentColor
        default: return .clear
        }
    }

    private var nativeShadow: Color {
        return theme.kind == .native ? pick(Color(red: 0.53, green: 0.55, blue: 0.58), Color.black.opacity(0.55)) : .clear
    }

    /// The accent glow, the raised key's drop shadow, or the native key's 1pt line.
    private var shadowStyle: (color: Color, radius: CGFloat, y: CGFloat) {
        switch keyGlow {
        case "soft": return (accentColor.opacity(0.55), 5, 0)
        case "strong": return (accentColor.opacity(0.95), 10, 0)
        default: break
        }
        if surface == "raised" { return (Color.black.opacity(dark ? 0.45 : 0.25), 1.5, 1.5) }
        return (nativeShadow, 0, 1)
    }
}

/// Builds the current theme's look (the chosen theme, accent and key style, in the phone's light or dark mode)
/// for the settings screens' previews, and redraws them when any of it changes.
struct CurrentThemeLook<Content: View>: View {
    @ViewBuilder let content: (ThemeLook) -> Content
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @AppStorage(SettingKey.keyRoundness, store: SharedStore.defaults) private var roundness = SettingDefault.keyRoundness
    @AppStorage(SettingKey.keySurface, store: SharedStore.defaults) private var keySurface = SettingDefault.keySurface
    @AppStorage(SettingKey.keyBorderStyle, store: SharedStore.defaults) private var keyBorderStyle = SettingDefault.keyBorderStyle
    @AppStorage(SettingKey.keyGlow, store: SharedStore.defaults) private var keyGlow = SettingDefault.keyGlow
    @Environment(\.colorScheme) private var scheme

    init(@ViewBuilder content: @escaping (ThemeLook) -> Content) {
        self.content = content
    }

    var body: some View {
        content(ThemeLook(theme: ThemeCatalog.theme(id: themeID),
                          accent: Color.currentAccent(name: accentName, hex: accentHex),
                          dark: scheme == .dark, roundness: roundness,
                          keySurface: keySurface, keyBorderStyle: keyBorderStyle, keyGlow: keyGlow,
                          accentHex: accentHex, accentName: accentName))
    }
}

extension KeyFont {
    /// The font in SwiftUI, as the keyboard's Theme.keyFont makes it (named fonts have one weight).
    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let name = postScriptName { return .custom(name, fixedSize: size) }
        switch self {
        case .rounded: return .system(size: size, weight: weight, design: .rounded)
        case .serif: return .system(size: size, weight: weight, design: .serif)
        case .mono: return .system(size: size, weight: weight, design: .monospaced)
        default: return .system(size: size, weight: weight)
        }
    }
}
