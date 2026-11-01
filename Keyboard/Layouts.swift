import Foundation
import CoreGraphics

// MARK: - Language layouts
//
// `Language` itself lives in Shared/Language.swift. The keyboard-only data (rows, accents) is here.

extension Language {

    /// The letter rows. Rows may have different lengths (e.g. Russian 12/11/9); the key view scales each row to the full width.
    var letterRows: [[String]] {
        func split(_ rows: String...) -> [[String]] {
            return rows.map { $0.map { String($0) } }
        }
        switch self {
        case .english, .italian:
            return split("qwertyuiop", "asdfghjkl", "zxcvbnm")
        case .hungarian, .czech:
            return split("qwertzuiop", "asdfghjkl", "yxcvbnm")
        case .spanish:
            return split("qwertyuiop", "asdfghjklñ", "zxcvbnm")
        case .french:
            return split("azertyuiop", "qsdfghjklm", "wxcvbn")
        case .german:
            return split("qwertzuiopü", "asdfghjklöä", "yxcvbnm")
        case .portuguese:
            return split("qwertyuiop", "asdfghjklç", "zxcvbnm")
        case .dutch, .polish, .romanian:
            return split("qwertyuiop", "asdfghjkl", "zxcvbnm")
        case .turkish:
            return split("qwertyuıopğü", "asdfghjklşi", "zxcvbnmöç")
        case .russian:
            return split("йцукенгшщзхъ", "фывапролджэ", "ячсмитьбю")
        case .ukrainian:
            return split("йцукенгшщзхї", "фівапролджє", "ячсмитьбюґ")
        case .swedish:
            return split("qwertyuiopå", "asdfghjklöä", "zxcvbnm")
        case .lithuanian, .cantonese:
            return split("qwertyuiop", "asdfghjkl", "zxcvbnm")
        case .danish:
            return split("qwertyuiopå", "asdfghjklæø", "zxcvbnm")
        case .norwegian:
            return split("qwertyuiopå", "asdfghjkløæ", "zxcvbnm")
        case .finnish:
            return split("qwertyuiopå", "asdfghjklöä", "zxcvbnm")
        case .greek:
            return split("ςερτυθιοπ", "ασδφγηξκλ", "ζχψωβνμ")
        case .hebrew:
            return split("קראטוןםפ", "שדגכעיחלךף", "זסבהנמצתץ")
        case .persian:
            return split("ضصثقفغعهخحجچ", "شسیبلاتنمکگ", "ظطژزرذدپو")
        case .indonesian:
            return split("qwertyuiop", "asdfghjkl", "zxcvbnm")
        case .malay:
            return split("qwertyuiop", "asdfghjkl", "zxcvbnm")
        case .vietnamese:
            return split("qwertyuiop", "asdfghjkl", "zxcvbnm")
        case .slovak:
            return split("qwertzuiop", "asdfghjkl", "yxcvbnm")
        case .croatian:
            return split("qwertzuiopšđ", "asdfghjklčćž", "yxcvbnm")
        case .bulgarian:
            return split("явертъуиопчш", "асдфгхйклщ", "зьцжбнмю")
        case .catalan:
            return split("qwertyuiop", "asdfghjklç", "zxcvbnm")
        case .mandarin:
            return split("qwertyuiop", "asdfghjkl", "zxcvbnm")
        case .japanese:
            return split("qwertyuiop", "asdfghjkl", "zxcvbnm")
        case .korean:
            return split("ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔ", "ㅁㄴㅇㄹㅎㅗㅓㅏㅣ", "ㅋㅌㅊㅍㅠㅜㅡ")
        case .hindi:
            return split("ौैाीूबहगदजड", "ोे्िुपरकतचट", "ंमनवलसयश")
        case .thai:
            return split("ภถุึคตจขช", "ๆไำพะัีรนยบล", "ฟหกดเ้่าสวง", "ผปแอิืทมใฝ")
        case .arabic:
            // Left to right as the keys appear (the Arabic PC layout; ذ from the key left of 1 starts the last row).
            return split("ضصثقفغعهخحجد", "شسيبلاتنمكط", "ذئءؤرىةوزظ")
        }
    }

    /// Accented / alternative characters offered on long-press. Only the ACTIVE language contributes.
    var accents: [String: [String]] {
        switch self {
        case .english:
            return [:]
        case .hungarian:
            return ["a": ["á"], "e": ["é"], "i": ["í"], "o": ["ó", "ö", "ő"], "u": ["ú", "ü", "ű"]]
        case .spanish:
            return ["a": ["á"], "e": ["é"], "i": ["í"], "o": ["ó"], "u": ["ú", "ü"]]
        case .french:
            return ["a": ["à", "â", "æ"], "e": ["é", "è", "ê", "ë"], "i": ["î", "ï"], "o": ["ô", "œ"],
                    "u": ["ù", "û", "ü"], "y": ["ÿ"], "c": ["ç"]]
        case .german:
            return ["s": ["ß"], "e": ["é"]]
        case .italian:
            return ["a": ["à"], "e": ["è", "é"], "i": ["ì", "í"], "o": ["ò", "ó"], "u": ["ù", "ú"]]
        case .portuguese:
            return ["a": ["á", "à", "â", "ã", "ä"], "e": ["é", "ê"], "i": ["í"], "o": ["ó", "ô", "õ"], "u": ["ú", "ü"]]
        case .dutch:
            return ["a": ["á", "ä"], "e": ["é", "ë"], "i": ["í", "ï"], "o": ["ó", "ö"], "u": ["ú", "ü"]]
        case .polish:
            return ["a": ["ą"], "c": ["ć"], "e": ["ę"], "l": ["ł"], "n": ["ń"], "o": ["ó"], "s": ["ś"], "z": ["ż", "ź"]]
        case .czech:
            return ["a": ["á"], "c": ["č"], "d": ["ď"], "e": ["é", "ě"], "i": ["í"], "n": ["ň"], "o": ["ó"],
                    "r": ["ř"], "s": ["š"], "t": ["ť"], "u": ["ú", "ů"], "y": ["ý"], "z": ["ž"]]
        case .romanian:
            return ["a": ["ă", "â"], "i": ["î"], "s": ["ș"], "t": ["ț"]]
        case .turkish:
            return ["a": ["â"], "i": ["î"], "u": ["û"]]
        case .russian:
            return ["е": ["ё"]]
        case .ukrainian:
            return [:]
        case .swedish:
            return ["e": ["é"], "u": ["ü"]]
        case .lithuanian:
            return ["a": ["ą"], "c": ["č"], "e": ["ę", "ė"], "i": ["į"], "s": ["š"], "u": ["ų", "ū"], "z": ["ž"]]
        case .arabic:
            // Hamza and madda forms of alef, and the other seats of hamza.
            return ["ا": ["أ", "إ", "آ", "ٱ"], "ي": ["ى", "ئ"], "و": ["ؤ"], "ه": ["ة"], "ء": ["أ", "إ", "ؤ", "ئ"]]
        case .cantonese:
            return [:]   // Jyutping is plain a-z
        case .danish:
            return ["e": ["é"], "o": ["ö"], "a": ["ä"]]
        case .norwegian:
            return ["e": ["é", "è", "ê"], "o": ["ó", "ò", "ô"]]
        case .finnish:
            return ["s": ["š"], "z": ["ž"]]
        case .greek:
            return ["α": ["ά"], "ε": ["έ"], "η": ["ή"], "ι": ["ί", "ϊ", "ΐ"], "ο": ["ό"], "υ": ["ύ", "ϋ", "ΰ"], "ω": ["ώ"]]
        case .hebrew:
            return [:]
        case .persian:
            return ["ا": ["آ", "أ", "إ"], "ی": ["ئ", "ي"], "و": ["ؤ"], "ه": ["ة", "ۀ"], "ک": ["ك"]]
        case .indonesian:
            return ["e": ["é"]]
        case .malay:
            return [:]
        case .vietnamese:
            return ["a": ["á", "à", "ả", "ã", "ạ", "ă", "â"], "e": ["é", "è", "ẻ", "ẽ", "ẹ", "ê"], "i": ["í", "ì", "ỉ", "ĩ", "ị"], "o": ["ó", "ò", "ỏ", "õ", "ọ", "ô", "ơ"], "u": ["ú", "ù", "ủ", "ũ", "ụ", "ư"], "y": ["ý", "ỳ", "ỷ", "ỹ", "ỵ"], "d": ["đ"]]
        case .slovak:
            return ["a": ["á", "ä"], "c": ["č"], "d": ["ď"], "e": ["é"], "i": ["í"], "l": ["ľ", "ĺ"], "n": ["ň"], "o": ["ó", "ô"], "r": ["ŕ"], "s": ["š"], "t": ["ť"], "u": ["ú"], "y": ["ý"], "z": ["ž"]]
        case .croatian:
            return [:]
        case .bulgarian:
            return ["и": ["ѝ"]]
        case .catalan:
            return ["a": ["à"], "e": ["è", "é"], "i": ["í", "ï"], "o": ["ò", "ó"], "u": ["ú", "ü"], "l": ["·"]]
        case .mandarin:
            return [:]
        case .japanese:
            return [:]
        case .korean:
            return ["ㅂ": ["ㅃ"], "ㅈ": ["ㅉ"], "ㄷ": ["ㄸ"], "ㄱ": ["ㄲ"], "ㅅ": ["ㅆ"], "ㅐ": ["ㅒ"], "ㅔ": ["ㅖ"]]
        case .hindi:
            return ["ा": ["आ"], "ि": ["इ"], "ी": ["ई"], "ु": ["उ"], "ू": ["ऊ"], "े": ["ए"], "ै": ["ऐ"], "ो": ["ओ", "ॉ", "ऑ"], "ौ": ["औ"], "्": ["अ", "ृ", "ऋ"], "ं": ["ँ", "ः"], "क": ["ख", "क़", "ख़"], "ग": ["घ", "ग़"], "ज": ["झ", "ज़", "ञ"], "त": ["थ", "त्र"], "द": ["ध"], "ट": ["ठ"], "ड": ["ढ", "ड़", "ढ़"], "प": ["फ", "फ़"], "ब": ["भ"], "च": ["छ"], "न": ["ण", "ङ"], "स": ["ष"], "श": ["क्ष", "ज्ञ", "श्र"], "ल": ["ळ"], "य": ["य़"]]
        case .thai:
            return ["เ": ["โ"], "ส": ["ศ", "ษ", "ซ"], "ท": ["ธ", "ฒ"], "น": ["ณ"], "ย": ["ญ"], "ด": ["ฎ"], "ต": ["ฏ"], "ถ": ["ฐ"], "ล": ["ฬ", "ฦ"], "ร": ["ฤ"], "ห": ["ฮ"], "่": ["๋", "๊", "์", "็"], "้": ["๊", "๋", "์", "็"], "ข": ["ฃ"], "ค": ["ฅ", "ฆ"], "ช": ["ฉ", "ซ"], "พ": ["ฑ"], "ะ": ["ฯ"], "ั": ["ํ"], "ุ": ["ู"], "ี": ["ื"]]
        }
    }

    /// Characters typed by the letter keys (lower case).
    var keyLetterSet: Set<Character> {
        var set = Set<Character>()
        for row in letterRows {
            for key in row {
                if let character = key.first { set.insert(character) }
            }
        }
        return set
    }

    /// Upper-case a string the way this language does it (Turkish i -> İ).
    func uppercase(_ text: String) -> String {
        if !hasCapitals { return text }
        if self == .turkish { return text.uppercased(with: Locale(identifier: "tr")) }
        return text.uppercased()
    }

    /// The language's own quotation marks (on the full stop's long-press: they open and close quoted sentences).
    var quoteMarks: [String] {
        switch self {
        case .hungarian, .polish, .romanian, .czech: return ["\u{201E}", "\u{201D}", "\u{00BB}", "\u{00AB}"]
        case .german: return ["\u{201E}", "\u{201C}", "\u{00BB}", "\u{00AB}"]
        case .french, .russian, .ukrainian: return ["\u{00AB}", "\u{00BB}"]
        case .swedish: return ["\u{201D}"]
        case .lithuanian: return ["\u{201E}", "\u{201C}"]
        case .arabic: return ["\u{00AB}", "\u{00BB}"]
        case .cantonese: return ["「", "」", "『", "』"]
        case .danish: return ["\u{00BB}", "\u{00AB}"]
        case .norwegian: return ["\u{00AB}", "\u{00BB}"]
        case .finnish: return ["\u{201D}"]
        case .greek: return ["\u{00AB}", "\u{00BB}"]
        case .hebrew: return ["\u{201E}", "\u{201D}"]
        case .persian: return ["\u{00AB}", "\u{00BB}"]
        case .slovak: return ["\u{201E}", "\u{201C}"]
        case .croatian: return ["\u{201E}", "\u{201C}", "\u{00BB}", "\u{00AB}"]
        case .bulgarian: return ["\u{201E}", "\u{201C}"]
        case .catalan: return ["\u{00AB}", "\u{00BB}"]
        case .mandarin: return ["\u{201C}", "\u{201D}", "\u{2018}", "\u{2019}", "\u{300A}", "\u{300B}"]
        case .japanese: return ["\u{300C}", "\u{300D}", "\u{300E}", "\u{300F}"]
        default: return []
        }
    }

    /// Currency symbols offered on the "$" key of the numbers page.
    var currencyOptions: [String] {
        switch self {
        case .hungarian: return ["Ft", "€", "£", "¥"]
        case .polish: return ["zł", "€", "£", "¥"]
        case .czech: return ["Kč", "€", "£", "¥"]
        case .romanian: return ["lei", "€", "£", "¥"]
        case .turkish: return ["₺", "€", "£", "¥"]
        case .swedish: return ["kr", "€", "£", "¥"]
        case .russian: return ["₽", "€", "£", "¥"]
        case .ukrainian: return ["₴", "€", "£", "¥"]
        case .arabic: return ["﷼", "€", "£", "¥"]
        case .cantonese: return ["HK$", "¥", "€", "£"]
        case .danish: return ["kr", "€", "£", "$"]
        case .norwegian: return ["kr", "€", "£", "$"]
        case .finnish: return ["€", "$", "£", "¥"]
        case .greek: return ["€", "$", "£", "¥"]
        case .hebrew: return ["₪", "$", "€", "£"]
        case .persian: return ["﷼", "$", "€", "£"]
        case .indonesian: return ["Rp", "$", "€", "£"]
        case .malay: return ["RM", "$", "€", "£"]
        case .vietnamese: return ["₫", "$", "€", "£"]
        case .slovak: return ["€", "Kč", "$", "£"]
        case .croatian: return ["€", "$", "£", "¥"]
        case .bulgarian: return ["лв", "€", "$", "£"]
        case .catalan: return ["€", "$", "£", "¥"]
        case .mandarin: return ["¥", "$", "€", "£"]
        case .japanese: return ["¥", "$", "€", "£"]
        case .korean: return ["₩", "$", "€", "£"]
        case .hindi: return ["₹", "$", "€", "£"]
        case .thai: return ["฿", "$", "€", "£"]
        default: return ["€", "£", "¥", "¢"]
        }
    }

    /// The language's own punctuation: Arabic turns the comma, question mark and semicolon ("،" "؟" "؛"); Chinese
    /// uses the full-width marks ("，" "。" "？" "！" "；").
    var comma: String {
        if usesArabicPunctuation { return "\u{060C}" }
        if self == .japanese { return "\u{3001}" }
        return usesPhoneticInput ? "\u{FF0C}" : ","
    }
    var questionMark: String {
        if usesArabicPunctuation { return "\u{061F}" }
        return usesPhoneticInput ? "\u{FF1F}" : "?"
    }
    var semicolon: String {
        if usesArabicPunctuation { return "\u{061B}" }
        return usesPhoneticInput ? "\u{FF1B}" : ";"
    }
    var fullStop: String {
        if self == .hindi { return "\u{0964}" }   // the danda ।
        return usesPhoneticInput ? "\u{3002}" : "."
    }
    var exclamation: String { return usesPhoneticInput ? "\u{FF01}" : "!" }

    /// Digits on the numbers page: Arabic-Indic for Arabic, their Persian forms for Persian (the Western ones on
    /// long-press), else 0-9.
    var digits: [String] {
        if self == .arabic { return ["١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩", "٠"] }
        if self == .persian { return ["۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹", "۰"] }
        return ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    }
}

// MARK: - Keys

enum KeyboardPage {
    case letters
    case numbers
    case symbols
}

enum ShiftState {
    case off
    case once
    case locked
}

enum KeyAction: Equatable {
    case character(String)
    case shift
    case backspace
    case space
    case enter
    case showLetters
    case showNumbers
    case showSymbols
    case emoji
    case spacer
}

struct KeySpec {
    var action: KeyAction
    var title: String = ""
    var symbol: String? = nil
    var weight: CGFloat = 1
    var alternates: [String] = []
    var isFunction: Bool = false
    var hint: String? = nil          // small character in the key's corner (first long-press option)

    var isSpacer: Bool { return action == .spacer }
}

// MARK: - Layout builder

enum LayoutBuilder {

    static func rows(language: Language,
                     page: KeyboardPage,
                     returnTitle: String,
                     numberRow: Bool,
                     showHints: Bool) -> [[KeySpec]] {
        switch page {
        case .letters:
            return letterPage(language: language, returnTitle: returnTitle, numberRow: numberRow, showHints: showHints)
        case .numbers:
            return numberPage(language: language, returnTitle: returnTitle)
        case .symbols:
            return symbolPage(language: language, returnTitle: returnTitle)
        }
    }

    // MARK: Letters

    private static func letterPage(language: Language,
                                   returnTitle: String,
                                   numberRow: Bool,
                                   showHints: Bool) -> [[KeySpec]] {
        let letters = language.letterRows
        let accents = language.accents

        func letterKey(_ letter: String) -> KeySpec {
            let alternates = accents[letter] ?? []
            return KeySpec(action: .character(letter),
                           title: letter,
                           alternates: alternates,
                           hint: showHints ? alternates.first : nil)
        }

        var result: [[KeySpec]] = []

        if numberRow {
            let digits = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
            result.append(digits.map { KeySpec(action: .character($0), title: $0) })
        }

        // Every row but the last is centred under the longest one (Thai has four rows of letters); the last has
        // shift and delete at its ends.
        let upper = letters.dropLast()
        let last = letters[letters.count - 1]
        let topCount = upper.map { $0.count }.max() ?? last.count
        for letterRow in upper {
            var row: [KeySpec] = []
            let sidePad = CGFloat(max(0, topCount - letterRow.count)) / 2
            if sidePad > 0 { row.append(KeySpec(action: .spacer, weight: sidePad)) }
            row.append(contentsOf: letterRow.map(letterKey))
            if sidePad > 0 { row.append(KeySpec(action: .spacer, weight: sidePad)) }
            result.append(row)
        }

        let edgeWeight = min(1.8, max(1.0, CGFloat(topCount - last.count) / 2))
        var row3: [KeySpec] = []
        if language.hasCapitals {
            row3.append(KeySpec(action: .shift, symbol: "shift", weight: edgeWeight, isFunction: true))
        }
        row3.append(contentsOf: last.map(letterKey))
        // Without a shift key (Arabic) the delete key takes its room too.
        let deleteWeight = language.hasCapitals ? edgeWeight : max(1.5, CGFloat(topCount - last.count))
        row3.append(KeySpec(action: .backspace, symbol: "delete.left", weight: deleteWeight, isFunction: true))
        result.append(row3)

        result.append([
            KeySpec(action: .showNumbers, title: "123", weight: 1.3, isFunction: true),
            KeySpec(action: .emoji, symbol: "face.smiling", weight: 1.0, isFunction: true),
            KeySpec(action: .character(language.comma), title: language.comma, weight: 1.0, alternates: commaAlternates(language)),
            KeySpec(action: .space, title: language.displayName, weight: 3.9),
            KeySpec(action: .character(language.fullStop), title: language.fullStop, weight: 1.0, alternates: dotAlternates(language)),
            KeySpec(action: .enter, title: returnTitle, weight: 1.8, isFunction: true)
        ])
        return result
    }

    /// Long-press options of the comma key.
    /// The comma's long-press: marks used inside a sentence.
    private static func commaAlternates(_ language: Language) -> [String] {
        var marks = [language.semicolon, ":", "'", "-", "\u{2013}", "(", ")"]
        if language.usesArabicPunctuation || language.usesPhoneticInput { marks.insert(",", at: 0) }
        if language == .japanese {
            marks.insert(contentsOf: ["\u{30FC}", "\u{FF0C}", "\u{30FB}"], at: 1)   // the long-vowel mark ー, ， and ・
        } else if language.usesPhoneticInput {
            marks.insert("\u{3001}", at: 1)   // the enumeration comma 、
        }
        if language == .ukrainian { marks.insert("\u{02BC}", at: 3) }   // the Ukrainian apostrophe
        return marks
    }

    /// The full stop's long-press: marks that end or start a sentence.
    private static func dotAlternates(_ language: Language) -> [String] {
        var marks = [language.questionMark, language.exclamation, "\u{2026}", "\""]
        if language.usesArabicPunctuation { marks.insert("?", at: 1) }
        if language.usesPhoneticInput { marks.insert(contentsOf: [".", "?", "!"], at: 0) }
        if language == .hindi { marks.insert(contentsOf: [".", "\u{0965}"], at: 0) }   // . and the double danda ॥
        if language == .spanish { marks.insert(contentsOf: ["\u{00BF}", "\u{00A1}"], at: 2) }   // ¿ ¡
        return marks + language.quoteMarks
    }

    // MARK: Numbers

    private static func numberPage(language: Language, returnTitle: String) -> [[KeySpec]] {
        let currency = language.currencyOptions

        // Arabic-Indic digits for Arabic, with the Western digit on long-press.
        let western = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        let row1 = zip(language.digits, western).map { digit, plain in
            KeySpec(action: .character(digit), title: digit, alternates: digit == plain ? [] : [plain])
        }

        var row2: [KeySpec] = []
        for symbol in ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""] {
            let alternates = (symbol == "$") ? currency : []
            row2.append(KeySpec(action: .character(symbol), title: symbol, alternates: alternates))
        }

        var row3: [KeySpec] = [KeySpec(action: .showSymbols, title: "#+=", weight: 1.5, isFunction: true)]
        for symbol in [language.fullStop, language.comma, language.questionMark, language.exclamation, "'"] {
            row3.append(KeySpec(action: .character(symbol), title: symbol, weight: 1.4))
        }
        row3.append(KeySpec(action: .backspace, symbol: "delete.left", weight: 1.5, isFunction: true))

        return [row1, row2, row3, bottomRow(language: language, pageKeyTitle: "ABC", returnTitle: returnTitle)]
    }

    // MARK: Symbols

    private static func symbolPage(language: Language, returnTitle: String) -> [[KeySpec]] {
        let row1 = ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="].map {
            KeySpec(action: .character($0), title: $0)
        }
        let row2 = ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"].map {
            KeySpec(action: .character($0), title: $0)
        }

        var row3: [KeySpec] = [KeySpec(action: .showNumbers, title: "123", weight: 1.5, isFunction: true)]
        for symbol in [language.fullStop, language.comma, language.questionMark, language.exclamation, "'"] {
            row3.append(KeySpec(action: .character(symbol), title: symbol, weight: 1.4))
        }
        row3.append(KeySpec(action: .backspace, symbol: "delete.left", weight: 1.5, isFunction: true))

        return [row1, row2, row3, bottomRow(language: language, pageKeyTitle: "ABC", returnTitle: returnTitle)]
    }

    private static func bottomRow(language: Language, pageKeyTitle: String, returnTitle: String) -> [KeySpec] {
        return [
            KeySpec(action: .showLetters, title: pageKeyTitle, weight: 1.3, isFunction: true),
            KeySpec(action: .emoji, symbol: "face.smiling", weight: 1.0, isFunction: true),
            KeySpec(action: .space, title: language.displayName, weight: 5.9),
            KeySpec(action: .enter, title: returnTitle, weight: 1.8, isFunction: true)
        ]
    }
}
