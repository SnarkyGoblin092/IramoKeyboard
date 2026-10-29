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
        if self == .turkish { return text.uppercased(with: Locale(identifier: "tr")) }
        return text.uppercased()
    }

    /// Extra options on the comma key's long-press (besides the common punctuation).
    var commaExtras: [String] {
        switch self {
        case .spanish: return ["¿", "¡"]
        case .hungarian, .polish, .romanian, .czech: return ["\u{201E}", "\u{201D}", "\u{00BB}", "\u{00AB}"]
        case .german: return ["\u{201E}", "\u{201C}", "\u{00BB}", "\u{00AB}"]
        case .french, .russian: return ["\u{00AB}", "\u{00BB}"]
        case .ukrainian: return ["\u{00AB}", "\u{00BB}", "\u{02BC}"]
        case .swedish: return ["\u{201D}"]
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
        default: return ["€", "£", "¥", "¢"]
        }
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

        let topCount = letters[0].count
        result.append(letters[0].map(letterKey))

        var row2: [KeySpec] = []
        let sidePad = CGFloat(max(0, topCount - letters[1].count)) / 2
        if sidePad > 0 { row2.append(KeySpec(action: .spacer, weight: sidePad)) }
        row2.append(contentsOf: letters[1].map(letterKey))
        if sidePad > 0 { row2.append(KeySpec(action: .spacer, weight: sidePad)) }
        result.append(row2)

        let edgeWeight = min(1.8, max(1.0, CGFloat(topCount - letters[2].count) / 2))
        var row3: [KeySpec] = [KeySpec(action: .shift, symbol: "shift", weight: edgeWeight, isFunction: true)]
        row3.append(contentsOf: letters[2].map(letterKey))
        row3.append(KeySpec(action: .backspace, symbol: "delete.left", weight: edgeWeight, isFunction: true))
        result.append(row3)

        result.append([
            KeySpec(action: .showNumbers, title: "123", weight: 1.3, isFunction: true),
            KeySpec(action: .emoji, symbol: "face.smiling", weight: 1.0, isFunction: true),
            KeySpec(action: .character(","), title: ",", weight: 1.0, alternates: commaAlternates(language)),
            KeySpec(action: .space, title: language.displayName, weight: 3.9),
            KeySpec(action: .character("."), title: ".", weight: 1.0,
                    alternates: [",", "?", "!", "'", "\"", ":", ";", "-"]),
            KeySpec(action: .enter, title: returnTitle, weight: 1.8, isFunction: true)
        ])
        return result
    }

    /// Long-press options of the comma key.
    private static func commaAlternates(_ language: Language) -> [String] {
        let common = ["?", "!", ";", ":", "'", "\""]
        return common + Array(language.commaExtras.prefix(2))
    }

    // MARK: Numbers

    private static func numberPage(language: Language, returnTitle: String) -> [[KeySpec]] {
        let currency = language.currencyOptions

        let row1 = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map {
            KeySpec(action: .character($0), title: $0)
        }

        var row2: [KeySpec] = []
        for symbol in ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""] {
            let alternates = (symbol == "$") ? currency : []
            row2.append(KeySpec(action: .character(symbol), title: symbol, alternates: alternates))
        }

        var row3: [KeySpec] = [KeySpec(action: .showSymbols, title: "#+=", weight: 1.5, isFunction: true)]
        for symbol in [".", ",", "?", "!", "'"] {
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
        for symbol in [".", ",", "?", "!", "'"] {
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
