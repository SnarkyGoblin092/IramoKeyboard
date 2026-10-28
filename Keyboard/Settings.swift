import Foundation

/// All user-adjustable options.
///
/// They are stored in the keyboard extension's own `UserDefaults`, which means no
/// App Group (and therefore no paid developer account) is needed. The options are
/// edited from the settings panel inside the keyboard (gear button).
final class Settings {
    static let shared = Settings()

    static let holdDelayRange: ClosedRange<Double> = 0.10...1.00

    private let defaults = UserDefaults.standard

    private enum Key {
        static let holdDelay = "hunkeys.holdDelay"
        static let vibration = "hunkeys.vibrationStrength"
        static let swipe = "hunkeys.swipeTyping"
        static let suggestions = "hunkeys.wordSuggestions"
        static let emojiSuggestions = "hunkeys.emojiSuggestions"
        static let autoCapitalize = "hunkeys.autoCapitalize"
        static let language = "hunkeys.language"
        static let recentEmoji = "hunkeys.recentEmoji"
        static let learned = "hunkeys.learned."
    }

    private init() {
        defaults.register(defaults: [
            Key.holdDelay: 0.35,
            Key.vibration: 0.5,
            Key.swipe: true,
            Key.suggestions: true,
            Key.emojiSuggestions: true,
            Key.autoCapitalize: true,
            Key.language: Language.english.rawValue
        ])
    }

    /// Seconds a key must be held before accents appear (also the delay before backspace repeats).
    var holdDelay: Double {
        get {
            let value = defaults.double(forKey: Key.holdDelay)
            return Swift.min(Swift.max(value, Settings.holdDelayRange.lowerBound), Settings.holdDelayRange.upperBound)
        }
        set { defaults.set(newValue, forKey: Key.holdDelay) }
    }

    /// 0 = no vibration, 1 = strongest.
    var vibrationStrength: Double {
        get { Swift.min(Swift.max(defaults.double(forKey: Key.vibration), 0), 1) }
        set { defaults.set(newValue, forKey: Key.vibration) }
    }

    var swipeEnabled: Bool {
        get { defaults.bool(forKey: Key.swipe) }
        set { defaults.set(newValue, forKey: Key.swipe) }
    }

    var suggestionsEnabled: Bool {
        get { defaults.bool(forKey: Key.suggestions) }
        set { defaults.set(newValue, forKey: Key.suggestions) }
    }

    var emojiSuggestionsEnabled: Bool {
        get { defaults.bool(forKey: Key.emojiSuggestions) }
        set { defaults.set(newValue, forKey: Key.emojiSuggestions) }
    }

    var autoCapitalize: Bool {
        get { defaults.bool(forKey: Key.autoCapitalize) }
        set { defaults.set(newValue, forKey: Key.autoCapitalize) }
    }

    var languageCode: String {
        get { defaults.string(forKey: Key.language) ?? Language.english.rawValue }
        set { defaults.set(newValue, forKey: Key.language) }
    }

    var recentEmoji: [String] {
        get { defaults.stringArray(forKey: Key.recentEmoji) ?? [] }
        set { defaults.set(newValue, forKey: Key.recentEmoji) }
    }

    func learnedWords(for languageCode: String) -> [String: Int] {
        return defaults.dictionary(forKey: Key.learned + languageCode) as? [String: Int] ?? [:]
    }

    func setLearnedWords(_ words: [String: Int], for languageCode: String) {
        defaults.set(words, forKey: Key.learned + languageCode)
    }

    func clearLearnedWords() {
        for language in Language.allCases {
            defaults.removeObject(forKey: Key.learned + language.rawValue)
        }
    }
}
