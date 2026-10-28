import Foundation

/// Every typing language the keyboard knows. Lives in Shared/ because the app lists the languages too.
/// (Layouts, accents and dictionaries are attached in Keyboard/Layouts.swift.)
enum Language: String, CaseIterable {
    case english = "en"
    case hungarian = "hu"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case dutch = "nl"
    case polish = "pl"
    case czech = "cs"
    case romanian = "ro"
    case turkish = "tr"
    case russian = "ru"
    case ukrainian = "uk"
    case swedish = "sv"

    /// The language's own name.
    var displayName: String {
        switch self {
        case .english: return "English"
        case .hungarian: return "Magyar"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .dutch: return "Nederlands"
        case .polish: return "Polski"
        case .czech: return "Čeština"
        case .romanian: return "Română"
        case .turkish: return "Türkçe"
        case .russian: return "Русский"
        case .ukrainian: return "Українська"
        case .swedish: return "Svenska"
        }
    }

    /// "EN", "HU", ...
    var shortCode: String { return rawValue.uppercased() }

    /// Languages from a list of ISO codes (unknown codes are ignored; never returns an empty list).
    static func list(from codes: [String], fallback: Language = .english) -> [Language] {
        var result: [Language] = []
        for code in codes {
            if let language = Language(rawValue: code), !result.contains(language) {
                result.append(language)
            }
        }
        return result.isEmpty ? [fallback] : result
    }
}
