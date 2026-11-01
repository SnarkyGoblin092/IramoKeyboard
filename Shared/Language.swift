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
    case lithuanian = "lt"
    case latvian = "lv"
    case uzbek = "uz"
    case arabic = "ar"
    case cantonese = "yue"
    case danish = "da"
    case norwegian = "no"
    case finnish = "fi"
    case greek = "el"
    case hebrew = "he"
    case persian = "fa"
    case indonesian = "id"
    case malay = "ms"
    case vietnamese = "vi"
    case slovak = "sk"
    case croatian = "hr"
    case bulgarian = "bg"
    case catalan = "ca"
    case mandarin = "zh"
    case japanese = "ja"
    case korean = "ko"
    case hindi = "hi"
    case thai = "th"

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
        case .lithuanian: return "Lietuvių"
        case .latvian: return "Latviešu"
        case .uzbek: return "Oʻzbekcha"
        case .arabic: return "العربية"
        case .cantonese: return "粵語"
        case .danish: return "Dansk"
        case .norwegian: return "Norsk"
        case .finnish: return "Suomi"
        case .greek: return "Ελληνικά"
        case .hebrew: return "עברית"
        case .persian: return "فارسی"
        case .indonesian: return "Bahasa Indonesia"
        case .malay: return "Bahasa Melayu"
        case .vietnamese: return "Tiếng Việt"
        case .slovak: return "Slovenčina"
        case .croatian: return "Hrvatski"
        case .bulgarian: return "Български"
        case .catalan: return "Català"
        case .mandarin: return "普通话 (简体)"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .hindi: return "हिन्दी"
        case .thai: return "ไทย"
        }
    }

    /// Written right to left (the cursor gesture is mirrored for it).
    var isRightToLeft: Bool { return self == .arabic || self == .hebrew || self == .persian }

    /// Uses the Arabic comma, question mark and semicolon ("،" "؟" "؛").
    var usesArabicPunctuation: Bool { return self == .arabic || self == .persian }

    /// Has capital letters (no shift key, auto-capitalization or capitalised suggestions without them).
    var hasCapitals: Bool {
        return !isRightToLeft && !usesPhoneticInput && self != .korean && self != .hindi && self != .thai
    }

    /// Typed by its sound and turned into characters picked from the suggestion bar (Keyboard/PhoneticInput.swift):
    /// Cantonese in Jyutping, Mandarin in Pinyin, Japanese in romaji (shown as kana while typing). No swiping,
    /// auto-correction or spaces between words.
    var usesPhoneticInput: Bool { return self == .cantonese || self == .mandarin || self == .japanese }

    /// Swiping across the letters works: the keys are the letters the words are written with. Not for Korean (its
    /// keys are jamo that build syllables), Hindi and Thai (their vowel signs combine with the letters), or the
    /// languages typed by sound.
    var supportsSwipe: Bool { return !usesPhoneticInput && self != .korean && self != .hindi && self != .thai }

    /// Words are auto-corrected on space. Not for Korean, whose syllables change as they are typed, nor Thai,
    /// written without spaces between words.
    var autoCorrects: Bool { return !usesPhoneticInput && self != .korean && self != .thai }

    /// Whether typing in this language can use `feature` (the keyboard leaves it out while typing in a language
    /// that can't; the app greys a setting out when none of the enabled languages can).
    func supports(_ feature: LanguageFeature) -> Bool {
        switch feature {
        case .swipe, .keyLearning: return supportsSwipe
        case .autoCorrect: return autoCorrects
        case .capitals: return hasCapitals
        // Chinese and Japanese need no space after a full stop; Thai ends sentences with a space, not a full stop.
        case .sentencePeriod: return !usesPhoneticInput && self != .thai
        }
    }

    /// How a language typed by sound is spelled ("Jyutping", "Pinyin"), shown in place of its layout.
    var phoneticSystem: String? {
        switch self {
        case .cantonese: return "Jyutping"
        case .mandarin: return "Pinyin"
        case .japanese: return "Romaji"
        default: return nil
        }
    }

    /// The enabled languages that can't use `feature`, and whether that is every one of them.
    static func lacking(_ feature: LanguageFeature, among languages: [Language]) -> (languages: [Language], all: Bool) {
        let lacking = languages.filter { !$0.supports(feature) }
        return (lacking, !languages.isEmpty && lacking.count == languages.count)
    }

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

/// Keyboard features that only work in some languages (`Language.supports`).
enum LanguageFeature {
    /// Swipe typing and its options: the keys must be the letters words are written with.
    case swipe
    case autoCorrect
    /// Auto-capitalization, flick up for a capital and capitals on the keys.
    case capitals
    /// Double space for a full stop.
    case sentencePeriod
    /// Adaptive keys and the hit map, which learn from words spelled with the keys' letters.
    case keyLearning
}
