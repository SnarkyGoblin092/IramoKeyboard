import Foundation
import CoreGraphics

// MARK: - Languages

enum Language: String, CaseIterable {
    case english = "en"
    case hungarian = "hu"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .hungarian: return "Magyar"
        }
    }

    var next: Language {
        let all = Language.allCases
        guard let index = all.firstIndex(of: self) else { return self }
        return all[(index + 1) % all.count]
    }

    /// The three letter rows. English is QWERTY, Hungarian is QWERTZ (y and z swapped).
    var letterRows: [[String]] {
        switch self {
        case .english:
            return [
                ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                ["z", "x", "c", "v", "b", "n", "m"]
            ]
        case .hungarian:
            return [
                ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p"],
                ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                ["y", "x", "c", "v", "b", "n", "m"]
            ]
        }
    }

    /// Accented characters offered on long-press. Only the ACTIVE language contributes,
    /// so English shows none and Hungarian shows exactly its own accents.
    var accents: [String: [String]] {
        switch self {
        case .english:
            return [:]
        case .hungarian:
            return [
                "a": ["á"],
                "e": ["é"],
                "i": ["í"],
                "o": ["ó", "ö", "ő"],
                "u": ["ú", "ü", "ű"]
            ]
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
    case nextLanguage
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

    var isSpacer: Bool { return action == .spacer }
}

// MARK: - Layout builder

enum LayoutBuilder {

    static func rows(language: Language, page: KeyboardPage, returnTitle: String) -> [[KeySpec]] {
        switch page {
        case .letters: return letterPage(language: language, returnTitle: returnTitle)
        case .numbers: return numberPage(language: language, returnTitle: returnTitle)
        case .symbols: return symbolPage(language: language, returnTitle: returnTitle)
        }
    }

    // MARK: Letters

    private static func letterPage(language: Language, returnTitle: String) -> [[KeySpec]] {
        let letters = language.letterRows
        let accents = language.accents

        func letterKey(_ letter: String) -> KeySpec {
            return KeySpec(action: .character(letter), title: letter, alternates: accents[letter] ?? [])
        }

        let row1: [KeySpec] = letters[0].map(letterKey)

        var row2: [KeySpec] = [KeySpec(action: .spacer, weight: 0.5)]
        row2.append(contentsOf: letters[1].map(letterKey))
        row2.append(KeySpec(action: .spacer, weight: 0.5))

        var row3: [KeySpec] = [KeySpec(action: .shift, symbol: "shift", weight: 1.5, isFunction: true)]
        row3.append(contentsOf: letters[2].map(letterKey))
        row3.append(KeySpec(action: .backspace, symbol: "delete.left", weight: 1.5, isFunction: true))

        let row4: [KeySpec] = [
            KeySpec(action: .showNumbers, title: "123", weight: 1.3, isFunction: true),
            KeySpec(action: .nextLanguage, symbol: "globe", weight: 1.0, isFunction: true),
            KeySpec(action: .emoji, symbol: "face.smiling", weight: 1.0, isFunction: true),
            KeySpec(action: .space, title: language.displayName, weight: 3.9),
            KeySpec(action: .character("."), title: ".", weight: 1.0,
                    alternates: [",", "?", "!", "'", "\"", ":", ";", "-"]),
            KeySpec(action: .enter, title: returnTitle, weight: 1.8, isFunction: true)
        ]

        return [row1, row2, row3, row4]
    }

    // MARK: Numbers

    private static func numberPage(language: Language, returnTitle: String) -> [[KeySpec]] {
        let currency: [String] = (language == .hungarian) ? ["Ft", "€", "£", "¥"] : ["€", "£", "¥", "¢"]

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
            KeySpec(action: .nextLanguage, symbol: "globe", weight: 1.0, isFunction: true),
            KeySpec(action: .emoji, symbol: "face.smiling", weight: 1.0, isFunction: true),
            KeySpec(action: .space, title: language.displayName, weight: 4.9),
            KeySpec(action: .enter, title: returnTitle, weight: 1.8, isFunction: true)
        ]
    }
}
