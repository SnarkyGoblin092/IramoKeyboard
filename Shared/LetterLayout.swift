import Foundation

/// Other arrangements of the letters for the languages written with the Latin a-z (the Languages screen sets one per
/// language). The language's own letters beyond a-z (ñ, ö, å...) stay at the end of the row they are on, so every
/// letter of the language is still on the keys.
enum LetterLayout: String, CaseIterable {
    case standard, qwerty, qwertz, azerty, dvorak, colemak, colemakDH, workman

    /// The name shown in the app (English keys for tr(); the layouts' own names are not translated).
    var displayName: String {
        switch self {
        case .standard: return "Language's own"
        case .qwerty: return "QWERTY"
        case .qwertz: return "QWERTZ"
        case .azerty: return "AZERTY"
        case .dvorak: return "Dvorak"
        case .colemak: return "Colemak"
        case .colemakDH: return "Colemak-DH"
        case .workman: return "Workman"
        }
    }

    /// A line on what the layout is for (English keys for tr()).
    var note: String {
        switch self {
        case .standard: return "The layout the language usually has."
        case .qwerty: return "The most common layout."
        case .qwertz: return "Z and Y swapped, as in Central Europe."
        case .azerty: return "The French layout."
        case .dvorak: return "Vowels under the left hand, common consonants under the right."
        case .colemak: return "QWERTY with the most used letters moved to the middle row."
        case .colemakDH: return "Colemak with D and H moved down, easier to reach."
        case .workman: return "Less sideways reaching than Colemak."
        }
    }

    /// The three rows of a-z, or nil for the language's own layout.
    private var baseRows: [String]? {
        switch self {
        case .standard: return nil
        case .qwerty: return ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        case .qwertz: return ["qwertzuiop", "asdfghjkl", "yxcvbnm"]
        case .azerty: return ["azertyuiop", "qsdfghjklm", "wxcvbn"]
        case .dvorak: return ["pyfgcrl", "aoeuidhtns", "qjkxbmwvz"]
        case .colemak: return ["qwfpgjluy", "arstdhneio", "zxcvbkm"]
        case .colemakDH: return ["qwfpbjluy", "arstgmneio", "zxcdvkh"]
        case .workman: return ["qdrwbjfup", "ashtgyneoi", "zxmcvkl"]
        }
    }

    private static let latin = Set("abcdefghijklmnopqrstuvwxyz".map { String($0) })

    /// Whether a language with these rows can take another layout: three rows holding every letter a-z.
    static func supports(_ rows: [[String]]) -> Bool {
        guard rows.count == 3 else { return false }
        return latin.isSubset(of: Set(rows.joined()))
    }

    /// The rows in this layout: a-z in its order, then the language's other letters of each row.
    func apply(to rows: [[String]]) -> [[String]] {
        guard let base = baseRows, LetterLayout.supports(rows) else { return rows }
        return (0..<3).map { index in
            base[index].map { String($0) } + rows[index].filter { !LetterLayout.latin.contains($0) }
        }
    }

    /// The layout stored for a language code (its own when none is).
    static func stored(in layouts: [String: String], for code: String) -> LetterLayout {
        return layouts[code].flatMap { LetterLayout(rawValue: $0) } ?? .standard
    }
}
