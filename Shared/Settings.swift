import Foundation

// MARK: - Keys and defaults (shared by the app's SwiftUI bindings and the keyboard)

enum SettingKey {
    // Feel
    static let holdDelay = "hunkeys.holdDelay"
    static let vibration = "hunkeys.vibrationStrength"
    static let clickSound = "hunkeys.clickSound"
    static let keyPopups = "hunkeys.keyPopups"
    // Typing
    static let swipe = "hunkeys.swipeTyping"
    static let suggestions = "hunkeys.wordSuggestions"
    static let emojiSuggestions = "hunkeys.emojiSuggestions"
    static let autoCapitalize = "hunkeys.autoCapitalize"
    static let doubleSpacePeriod = "hunkeys.doubleSpacePeriod"
    static let cursorControl = "hunkeys.cursorControl"
    static let deleteSwipe = "hunkeys.deleteSwipe"
    // Layout and look
    static let numberRow = "hunkeys.numberRow"
    static let keyHints = "hunkeys.keyHints"
    static let theme = "hunkeys.theme"
    static let accent = "hunkeys.accent"
    static let keyboardHeight = "hunkeys.keyboardHeight"
    static let oneHanded = "hunkeys.oneHanded"
    // Data
    static let language = "hunkeys.language"
    static let enabledLanguages = "hunkeys.enabledLanguages"
    static let recentEmoji = "hunkeys.recentEmoji"
    static let shortcuts = "hunkeys.shortcuts"
    static let learnedPrefix = "hunkeys.learned."
    // Written by the keyboard so the app can show its status
    static let lastSeen = "hunkeys.status.lastSeen"
    static let fullAccess = "hunkeys.status.fullAccess"
    static let emojiVersion = "hunkeys.status.emojiVersion"
    static let emojiTotal = "hunkeys.status.emojiTotal"
    static let emojiShown = "hunkeys.status.emojiShown"

    /// Everything "Reset settings" puts back to its default (data like shortcuts is left alone).
    static let preferenceKeys: [String] = [
        holdDelay, vibration, clickSound, keyPopups, swipe, suggestions, emojiSuggestions,
        autoCapitalize, doubleSpacePeriod, cursorControl, deleteSwipe, numberRow, keyHints,
        theme, accent, keyboardHeight, oneHanded, enabledLanguages
    ]
}

enum SettingDefault {
    static let holdDelay = 0.35
    static let vibration = 0.5
    static let clickSound = false
    static let keyPopups = true
    static let swipe = true
    static let suggestions = true
    static let emojiSuggestions = true
    static let autoCapitalize = true
    static let doubleSpacePeriod = true
    static let cursorControl = true
    static let deleteSwipe = true
    static let numberRow = false
    static let keyHints = true
    static let theme = "native"
    static let accent = "blue"
    static let keyboardHeight = 1.0
    static let oneHanded = "off"
    static let language = "en"
    static let enabledLanguages = ["en", "hu"]
}

enum AccentChoice: String, CaseIterable {
    case blue, teal, green, orange, pink, purple

    var rgb: (red: Double, green: Double, blue: Double) {
        switch self {
        case .blue: return (0.04, 0.52, 1.00)
        case .teal: return (0.19, 0.69, 0.78)
        case .green: return (0.19, 0.78, 0.35)
        case .orange: return (1.00, 0.62, 0.04)
        case .pink: return (1.00, 0.22, 0.37)
        case .purple: return (0.75, 0.35, 0.95)
        }
    }

    var displayName: String { return rawValue.capitalized }
}

/// "omw" -> "On my way!"
struct TextShortcut: Codable, Identifiable, Hashable {
    var id = UUID()
    var trigger: String
    var phrase: String
}

// MARK: - Settings

/// Reads and writes every option. Values are read on demand (never cached) so a change made in the
/// app shows up the next time the keyboard asks.
final class Settings {
    static let shared = Settings()

    static let holdDelayRange: ClosedRange<Double> = 0.10...1.00
    static let heightScaleRange: ClosedRange<Double> = 0.85...1.20

    private var store: UserDefaults { return SharedStore.defaults }

    private init() {
        SharedStore.defaults.register(defaults: [
            SettingKey.holdDelay: SettingDefault.holdDelay,
            SettingKey.vibration: SettingDefault.vibration,
            SettingKey.clickSound: SettingDefault.clickSound,
            SettingKey.keyPopups: SettingDefault.keyPopups,
            SettingKey.swipe: SettingDefault.swipe,
            SettingKey.suggestions: SettingDefault.suggestions,
            SettingKey.emojiSuggestions: SettingDefault.emojiSuggestions,
            SettingKey.autoCapitalize: SettingDefault.autoCapitalize,
            SettingKey.doubleSpacePeriod: SettingDefault.doubleSpacePeriod,
            SettingKey.cursorControl: SettingDefault.cursorControl,
            SettingKey.deleteSwipe: SettingDefault.deleteSwipe,
            SettingKey.numberRow: SettingDefault.numberRow,
            SettingKey.keyHints: SettingDefault.keyHints,
            SettingKey.theme: SettingDefault.theme,
            SettingKey.enabledLanguages: SettingDefault.enabledLanguages,
            SettingKey.accent: SettingDefault.accent,
            SettingKey.keyboardHeight: SettingDefault.keyboardHeight,
            SettingKey.oneHanded: SettingDefault.oneHanded,
            SettingKey.language: SettingDefault.language
        ])
    }

    private func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        return min(max(value, range.lowerBound), range.upperBound)
    }

    // MARK: Feel

    /// Seconds a key must be held before accents (or cursor control) start; also the delay before
    /// backspace begins repeating.
    var holdDelay: Double {
        get { return clamp(store.double(forKey: SettingKey.holdDelay), Settings.holdDelayRange) }
        set { store.set(clamp(newValue, Settings.holdDelayRange), forKey: SettingKey.holdDelay) }
    }

    /// 0 = no vibration, 1 = strongest.
    var vibrationStrength: Double {
        get { return clamp(store.double(forKey: SettingKey.vibration), 0...1) }
        set { store.set(clamp(newValue, 0...1), forKey: SettingKey.vibration) }
    }

    var clickSound: Bool {
        get { return store.bool(forKey: SettingKey.clickSound) }
        set { store.set(newValue, forKey: SettingKey.clickSound) }
    }

    var keyPopups: Bool {
        get { return store.bool(forKey: SettingKey.keyPopups) }
        set { store.set(newValue, forKey: SettingKey.keyPopups) }
    }

    // MARK: Typing

    var swipeEnabled: Bool {
        get { return store.bool(forKey: SettingKey.swipe) }
        set { store.set(newValue, forKey: SettingKey.swipe) }
    }

    var suggestionsEnabled: Bool {
        get { return store.bool(forKey: SettingKey.suggestions) }
        set { store.set(newValue, forKey: SettingKey.suggestions) }
    }

    var emojiSuggestionsEnabled: Bool {
        get { return store.bool(forKey: SettingKey.emojiSuggestions) }
        set { store.set(newValue, forKey: SettingKey.emojiSuggestions) }
    }

    var autoCapitalize: Bool {
        get { return store.bool(forKey: SettingKey.autoCapitalize) }
        set { store.set(newValue, forKey: SettingKey.autoCapitalize) }
    }

    var doubleSpacePeriod: Bool {
        get { return store.bool(forKey: SettingKey.doubleSpacePeriod) }
        set { store.set(newValue, forKey: SettingKey.doubleSpacePeriod) }
    }

    var cursorControl: Bool {
        get { return store.bool(forKey: SettingKey.cursorControl) }
        set { store.set(newValue, forKey: SettingKey.cursorControl) }
    }

    var deleteSwipe: Bool {
        get { return store.bool(forKey: SettingKey.deleteSwipe) }
        set { store.set(newValue, forKey: SettingKey.deleteSwipe) }
    }

    // MARK: Layout and look

    var numberRow: Bool {
        get { return store.bool(forKey: SettingKey.numberRow) }
        set { store.set(newValue, forKey: SettingKey.numberRow) }
    }

    var keyHints: Bool {
        get { return store.bool(forKey: SettingKey.keyHints) }
        set { store.set(newValue, forKey: SettingKey.keyHints) }
    }

    /// "native" (iOS look) or "transparent" (see-through keys).
    var theme: String {
        get {
            let value = store.string(forKey: SettingKey.theme) ?? SettingDefault.theme
            return value == "transparent" ? "transparent" : "native"
        }
        set { store.set(newValue, forKey: SettingKey.theme) }
    }

    var isTransparentTheme: Bool { return theme == "transparent" }

    var accentName: String {
        get { return store.string(forKey: SettingKey.accent) ?? SettingDefault.accent }
        set { store.set(newValue, forKey: SettingKey.accent) }
    }

    var accent: AccentChoice { return AccentChoice(rawValue: accentName) ?? .blue }

    var keyboardHeightScale: Double {
        get { return clamp(store.double(forKey: SettingKey.keyboardHeight), Settings.heightScaleRange) }
        set { store.set(clamp(newValue, Settings.heightScaleRange), forKey: SettingKey.keyboardHeight) }
    }

    /// "off", "left" or "right".
    var oneHanded: String {
        get { return store.string(forKey: SettingKey.oneHanded) ?? SettingDefault.oneHanded }
        set { store.set(newValue, forKey: SettingKey.oneHanded) }
    }

    // MARK: Data

    var languageCode: String {
        get { return store.string(forKey: SettingKey.language) ?? SettingDefault.language }
        set { store.set(newValue, forKey: SettingKey.language) }
    }

    var recentEmoji: [String] {
        get { return store.stringArray(forKey: SettingKey.recentEmoji) ?? [] }
        set { store.set(newValue, forKey: SettingKey.recentEmoji) }
    }

    func learnedWords(for languageCode: String) -> [String: Int] {
        return store.dictionary(forKey: SettingKey.learnedPrefix + languageCode) as? [String: Int] ?? [:]
    }

    func setLearnedWords(_ words: [String: Int], for languageCode: String) {
        store.set(words, forKey: SettingKey.learnedPrefix + languageCode)
    }

    func clearLearnedWords() {
        for language in Language.allCases {
            store.removeObject(forKey: SettingKey.learnedPrefix + language.rawValue)
        }
    }

    func clearRecentEmoji() {
        store.removeObject(forKey: SettingKey.recentEmoji)
    }

    var shortcuts: [TextShortcut] {
        get {
            guard let data = store.data(forKey: SettingKey.shortcuts),
                  let list = try? JSONDecoder().decode([TextShortcut].self, from: data) else {
                return []
            }
            return list
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                store.set(data, forKey: SettingKey.shortcuts)
            }
        }
    }

    /// The phrase a typed word expands to, if the user defined a shortcut for it.
    func shortcutPhrase(for typed: String) -> String? {
        let key = typed.lowercased()
        guard !key.isEmpty else { return nil }
        for shortcut in shortcuts where shortcut.trigger.lowercased() == key {
            return shortcut.phrase
        }
        return nil
    }

    func resetPreferences() {
        for key in SettingKey.preferenceKeys {
            store.removeObject(forKey: key)
        }
    }

    // MARK: Status (keyboard writes, app reads)

    func markKeyboardSeen(hasFullAccess: Bool) {
        store.set(Date().timeIntervalSince1970, forKey: SettingKey.lastSeen)
        store.set(hasFullAccess, forKey: SettingKey.fullAccess)
    }

    func recordEmojiStats(version: String, total: Int, shown: Int) {
        store.set(version, forKey: SettingKey.emojiVersion)
        store.set(total, forKey: SettingKey.emojiTotal)
        store.set(shown, forKey: SettingKey.emojiShown)
    }

    // MARK: Languages

    /// ISO codes of the languages shown in the keyboard's language switcher. Never empty.
    var enabledLanguages: [String] {
        get {
            let stored = store.stringArray(forKey: SettingKey.enabledLanguages) ?? SettingDefault.enabledLanguages
            return Language.list(from: stored, fallback: .english).map { $0.rawValue }
        }
        set {
            store.set(Language.list(from: newValue, fallback: .english).map { $0.rawValue },
                      forKey: SettingKey.enabledLanguages)
        }
    }
}
