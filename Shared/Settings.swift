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
    static let keyRoundness = "hunkeys.keyRoundness"
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
        theme, accent, keyboardHeight, keyRoundness, oneHanded, enabledLanguages
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
    static let keyRoundness = 0.26
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

/// Reads and writes every option. Reads come from a snapshot of the shared defaults that is refreshed
/// at most every half second (hot paths in the keyboard read settings constantly), so a change made in
/// the app shows up within ~0.5 s. Writes update the snapshot immediately. Call `refresh()` to force a re-read.
final class Settings {
    static let shared = Settings()

    static let holdDelayRange: ClosedRange<Double> = 0.10...1.00
    static let heightScaleRange: ClosedRange<Double> = 0.85...1.20

    private var store: UserDefaults { return SharedStore.defaults }

    // MARK: Snapshot cache

    private let lock = NSLock()
    private var snapshot: [String: Any] = [:]
    private var snapshotTime: CFAbsoluteTime = 0
    private let cacheLifetime: CFAbsoluteTime = 0.5

    /// Forces the next read to go back to the shared defaults.
    func refresh() {
        lock.lock()
        snapshotTime = 0
        lock.unlock()
    }

    private func value(_ key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        let now = CFAbsoluteTimeGetCurrent()
        if snapshot.isEmpty || now - snapshotTime > cacheLifetime || now < snapshotTime {
            snapshot = store.dictionaryRepresentation()
            snapshotTime = now
        }
        return snapshot[key]
    }

    private func put(_ newValue: Any?, _ key: String) {
        lock.lock()
        defer { lock.unlock() }
        if let newValue = newValue {
            store.set(newValue, forKey: key)
            snapshot[key] = newValue
        } else {
            store.removeObject(forKey: key)
            snapshot.removeValue(forKey: key)
        }
    }

    private func readDouble(_ key: String) -> Double {
        if let number = value(key) as? NSNumber { return number.doubleValue }
        if let number = value(key) as? Double { return number }
        return 0
    }

    private func readBool(_ key: String) -> Bool {
        if let number = value(key) as? NSNumber { return number.boolValue }
        if let flag = value(key) as? Bool { return flag }
        return false
    }

    private func readString(_ key: String) -> String? { return value(key) as? String }
    private func readStringArray(_ key: String) -> [String]? { return value(key) as? [String] }
    private func readData(_ key: String) -> Data? { return value(key) as? Data }

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
            SettingKey.keyRoundness: SettingDefault.keyRoundness,
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
        get { return clamp(readDouble(SettingKey.holdDelay), Settings.holdDelayRange) }
        set { put(clamp(newValue, Settings.holdDelayRange), SettingKey.holdDelay) }
    }

    /// 0 = no vibration, 1 = strongest.
    var vibrationStrength: Double {
        get { return clamp(readDouble(SettingKey.vibration), 0...1) }
        set { put(clamp(newValue, 0...1), SettingKey.vibration) }
    }

    var clickSound: Bool {
        get { return readBool(SettingKey.clickSound) }
        set { put(newValue, SettingKey.clickSound) }
    }

    var keyPopups: Bool {
        get { return readBool(SettingKey.keyPopups) }
        set { put(newValue, SettingKey.keyPopups) }
    }

    // MARK: Typing

    var swipeEnabled: Bool {
        get { return readBool(SettingKey.swipe) }
        set { put(newValue, SettingKey.swipe) }
    }

    var suggestionsEnabled: Bool {
        get { return readBool(SettingKey.suggestions) }
        set { put(newValue, SettingKey.suggestions) }
    }

    var emojiSuggestionsEnabled: Bool {
        get { return readBool(SettingKey.emojiSuggestions) }
        set { put(newValue, SettingKey.emojiSuggestions) }
    }

    var autoCapitalize: Bool {
        get { return readBool(SettingKey.autoCapitalize) }
        set { put(newValue, SettingKey.autoCapitalize) }
    }

    var doubleSpacePeriod: Bool {
        get { return readBool(SettingKey.doubleSpacePeriod) }
        set { put(newValue, SettingKey.doubleSpacePeriod) }
    }

    var cursorControl: Bool {
        get { return readBool(SettingKey.cursorControl) }
        set { put(newValue, SettingKey.cursorControl) }
    }

    var deleteSwipe: Bool {
        get { return readBool(SettingKey.deleteSwipe) }
        set { put(newValue, SettingKey.deleteSwipe) }
    }

    // MARK: Layout and look

    var numberRow: Bool {
        get { return readBool(SettingKey.numberRow) }
        set { put(newValue, SettingKey.numberRow) }
    }

    var keyHints: Bool {
        get { return readBool(SettingKey.keyHints) }
        set { put(newValue, SettingKey.keyHints) }
    }

    /// A theme id from `ThemeCatalog` ("native" by default; unknown ids fall back to native).
    var theme: String {
        get { return ThemeCatalog.theme(id: readString(SettingKey.theme) ?? SettingDefault.theme).id }
        set { put(newValue, SettingKey.theme) }
    }

    var isTransparentTheme: Bool { return theme == "transparent" }

    var themeDefinition: ThemeDefinition { return ThemeCatalog.theme(id: theme) }

    var accentName: String {
        get { return readString(SettingKey.accent) ?? SettingDefault.accent }
        set { put(newValue, SettingKey.accent) }
    }

    var accent: AccentChoice { return AccentChoice(rawValue: accentName) ?? .blue }

    /// 0 = square keys ... 1 = fully round (pill) keys.
    var keyRoundness: Double {
        get { return clamp(readDouble(SettingKey.keyRoundness), 0...1) }
        set { put(clamp(newValue, 0...1), SettingKey.keyRoundness) }
    }

    var keyboardHeightScale: Double {
        get { return clamp(readDouble(SettingKey.keyboardHeight), Settings.heightScaleRange) }
        set { put(clamp(newValue, Settings.heightScaleRange), SettingKey.keyboardHeight) }
    }

    /// "off", "left" or "right".
    var oneHanded: String {
        get { return readString(SettingKey.oneHanded) ?? SettingDefault.oneHanded }
        set { put(newValue, SettingKey.oneHanded) }
    }

    // MARK: Data

    var languageCode: String {
        get { return readString(SettingKey.language) ?? SettingDefault.language }
        set { put(newValue, SettingKey.language) }
    }

    var recentEmoji: [String] {
        get { return readStringArray(SettingKey.recentEmoji) ?? [] }
        set { put(newValue, SettingKey.recentEmoji) }
    }

    func learnedWords(for languageCode: String) -> [String: Int] {
        return value(SettingKey.learnedPrefix + languageCode) as? [String: Int] ?? [:]
    }

    func setLearnedWords(_ words: [String: Int], for languageCode: String) {
        put(words, SettingKey.learnedPrefix + languageCode)
    }

    func clearLearnedWords() {
        for language in Language.allCases {
            put(nil, SettingKey.learnedPrefix + language.rawValue)
        }
    }

    func clearRecentEmoji() {
        put(nil, SettingKey.recentEmoji)
    }

    var shortcuts: [TextShortcut] {
        get {
            guard let data = readData(SettingKey.shortcuts),
                  let list = try? JSONDecoder().decode([TextShortcut].self, from: data) else {
                return []
            }
            return list
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                put(data, SettingKey.shortcuts)
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
            put(nil, key)
        }
    }

    // MARK: Status (keyboard writes, app reads)

    func markKeyboardSeen(hasFullAccess: Bool) {
        put(Date().timeIntervalSince1970, SettingKey.lastSeen)
        put(hasFullAccess, SettingKey.fullAccess)
    }

    func recordEmojiStats(version: String, total: Int, shown: Int) {
        put(version, SettingKey.emojiVersion)
        put(total, SettingKey.emojiTotal)
        put(shown, SettingKey.emojiShown)
    }

    // MARK: Languages

    /// ISO codes of the languages shown in the keyboard's language switcher. Never empty.
    var enabledLanguages: [String] {
        get {
            let stored = readStringArray(SettingKey.enabledLanguages) ?? SettingDefault.enabledLanguages
            return Language.list(from: stored, fallback: .english).map { $0.rawValue }
        }
        set {
            put(Language.list(from: newValue, fallback: .english).map { $0.rawValue },
                SettingKey.enabledLanguages)
        }
    }
}
