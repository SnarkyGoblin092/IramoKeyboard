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
    static let autoCorrect = "hunkeys.autoCorrect"
    static let cursorControl = "hunkeys.cursorControl"
    static let deleteSwipe = "hunkeys.deleteSwipe"
    // Layout and look
    static let numberRow = "hunkeys.numberRow"
    static let keyHints = "hunkeys.keyHints"
    static let theme = "hunkeys.theme"
    static let accent = "hunkeys.accent"
    static let accentHex = "hunkeys.accentHex"
    static let keyboardHeight = "hunkeys.keyboardHeight"
    static let keyRoundness = "hunkeys.keyRoundness"
    static let oneHanded = "hunkeys.oneHanded"
    // Data
    static let language = "hunkeys.language"
    static let enabledLanguages = "hunkeys.enabledLanguages"
    static let recentEmoji = "hunkeys.recentEmoji"
    static let shortcuts = "hunkeys.shortcuts"
    static let keyBorders = "hunkeys.keyBorders"
    /// The learned key-offset model (data written by the keyboard; not a preference).
    static let touchModel = "hunkeys.touchModel"
    static let learnedPrefix = "hunkeys.learned."
    /// "typed\tmeant" -> how often the user deleted the typed word and wrote the meant one in its place.
    static let correctionsPrefix = "hunkeys.corrections."
    static let bigramPrefix = "hunkeys.bigrams."
    static let trigramPrefix = "hunkeys.trigrams."
    static let usagePrefix = "hunkeys.learnedDays."
    static let usedWordsPrefix = "hunkeys.usedWords."
    /// language code -> how much of what the user writes is in it (recent words count most).
    static let languageUsage = "hunkeys.languageUsage"
    // Written by the keyboard so the app can show its status
    static let lastSeen = "hunkeys.status.lastSeen"
    static let fullAccess = "hunkeys.status.fullAccess"
    static let emojiVersion = "hunkeys.status.emojiVersion"
    static let emojiTotal = "hunkeys.status.emojiTotal"
    static let emojiShown = "hunkeys.status.emojiShown"

    /// Everything "Reset settings" puts back to its default (data like shortcuts is left alone).
    static let preferenceKeys: [String] = [
        holdDelay, vibration, clickSound, keyPopups, swipe, suggestions, emojiSuggestions,
        autoCapitalize, doubleSpacePeriod, autoCorrect, cursorControl, deleteSwipe, numberRow, keyHints,
        theme, accent, accentHex, keyboardHeight, keyRoundness, oneHanded, enabledLanguages, keyBorders
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
    static let autoCorrect = true
    static let cursorControl = true
    static let deleteSwipe = true
    static let numberRow = false
    static let keyHints = true
    static let theme = "native"
    static let accent = "blue"
    static let accentHex = ""
    static let keyBorders = true
    static let keyboardHeight = 1.0
    static let keyRoundness = 0.26
    static let oneHanded = "off"
    static let language = "en"
    static let enabledLanguages = ["en", "hu"]
}

enum AccentChoice: String, CaseIterable {
    case blue, indigo, purple, pink, red, orange, yellow, green, mint, teal, cyan, graphite

    var rgb: (red: Double, green: Double, blue: Double) {
        switch self {
        case .blue: return (0.04, 0.52, 1.00)
        case .indigo: return (0.35, 0.34, 0.84)
        case .purple: return (0.75, 0.35, 0.95)
        case .pink: return (1.00, 0.22, 0.37)
        case .red: return (1.00, 0.27, 0.23)
        case .orange: return (1.00, 0.62, 0.04)
        case .yellow: return (1.00, 0.80, 0.00)
        case .green: return (0.19, 0.78, 0.35)
        case .mint: return (0.00, 0.78, 0.70)
        case .teal: return (0.19, 0.69, 0.78)
        case .cyan: return (0.20, 0.68, 0.90)
        case .graphite: return (0.56, 0.56, 0.58)
        }
    }

    var displayName: String { return rawValue.capitalized }
}

/// "#RRGGBB" helpers shared by the app's colour pickers and the keyboard.
enum HexColor {
    static func parse(_ text: String) -> (red: Double, green: Double, blue: Double)? {
        var hex = text.trimmingCharacters(in: .whitespaces)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        return (Double((value >> 16) & 0xFF) / 255.0,
                Double((value >> 8) & 0xFF) / 255.0,
                Double(value & 0xFF) / 255.0)
    }

    static func string(red: Double, green: Double, blue: Double) -> String {
        func byte(_ x: Double) -> Int { return Int((min(max(x, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
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
            SettingKey.autoCorrect: SettingDefault.autoCorrect,
            SettingKey.cursorControl: SettingDefault.cursorControl,
            SettingKey.deleteSwipe: SettingDefault.deleteSwipe,
            SettingKey.numberRow: SettingDefault.numberRow,
            SettingKey.keyHints: SettingDefault.keyHints,
            SettingKey.theme: SettingDefault.theme,
            SettingKey.enabledLanguages: SettingDefault.enabledLanguages,
            SettingKey.accent: SettingDefault.accent,
            SettingKey.accentHex: SettingDefault.accentHex,
            SettingKey.keyBorders: SettingDefault.keyBorders,
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

    var autoCorrect: Bool {
        get { return readBool(SettingKey.autoCorrect) }
        set { put(newValue, SettingKey.autoCorrect) }
    }

    var cursorControl: Bool {
        get { return readBool(SettingKey.cursorControl) }
        set { put(newValue, SettingKey.cursorControl) }
    }

    var deleteSwipe: Bool {
        get { return readBool(SettingKey.deleteSwipe) }
        set { put(newValue, SettingKey.deleteSwipe) }
    }

    var keyBorders: Bool {
        get { return readBool(SettingKey.keyBorders) }
        set { put(newValue, SettingKey.keyBorders) }
    }

    /// Removes what the old adaptive key areas stored (the feature is gone).
    func removeTouchModel() {
        guard SharedStore.defaults.object(forKey: SettingKey.touchModel) != nil
                || SharedStore.defaults.object(forKey: "hunkeys.touchLearning") != nil else { return }
        put(nil, SettingKey.touchModel)
        put(nil, "hunkeys.touchLearning")
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

    /// A custom accent colour as "#RRGGBB"; empty means "use the preset in `accentName`".
    var accentHex: String {
        get { return readString(SettingKey.accentHex) ?? SettingDefault.accentHex }
        set { put(newValue, SettingKey.accentHex) }
    }

    /// The accent actually in use: the custom colour if one is set and valid, else the preset.
    var accentRGB: (red: Double, green: Double, blue: Double) {
        if let custom = HexColor.parse(accentHex) { return custom }
        return accent.rgb
    }

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

    func corrections(for languageCode: String) -> [String: Int] {
        return value(SettingKey.correctionsPrefix + languageCode) as? [String: Int] ?? [:]
    }

    func setCorrections(_ corrections: [String: Int], for languageCode: String) {
        put(corrections, SettingKey.correctionsPrefix + languageCode)
    }

    /// Word pairs ("thank you") the user typed, as "first second" -> count, used for next-word suggestions.
    func learnedBigrams(for languageCode: String) -> [String: Int] {
        return value(SettingKey.bigramPrefix + languageCode) as? [String: Int] ?? [:]
    }

    func setLearnedBigrams(_ pairs: [String: Int], for languageCode: String) {
        put(pairs, SettingKey.bigramPrefix + languageCode)
    }

    /// Word triples ("thank you very") as "first second third" -> count.
    func learnedTrigrams(for languageCode: String) -> [String: Int] {
        return value(SettingKey.trigramPrefix + languageCode) as? [String: Int] ?? [:]
    }

    func setLearnedTrigrams(_ triples: [String: Int], for languageCode: String) {
        put(triples, SettingKey.trigramPrefix + languageCode)
    }

    /// Last day (days since 1970) each learned word / pair / triple was used, for recency weighting.
    func learnedUsage(for languageCode: String) -> [String: Int] {
        return value(SettingKey.usagePrefix + languageCode) as? [String: Int] ?? [:]
    }

    func setLearnedUsage(_ days: [String: Int], for languageCode: String) {
        put(days, SettingKey.usagePrefix + languageCode)
    }

    /// Dictionary words the user wrote -> count, so suggestions favour their own vocabulary.
    func usedWords(for languageCode: String) -> [String: Int] {
        return value(SettingKey.usedWordsPrefix + languageCode) as? [String: Int] ?? [:]
    }

    func setUsedWords(_ words: [String: Int], for languageCode: String) {
        put(words, SettingKey.usedWordsPrefix + languageCode)
    }

    func languageUsage() -> [String: Double] {
        return value(SettingKey.languageUsage) as? [String: Double] ?? [:]
    }

    func setLanguageUsage(_ usage: [String: Double]) {
        put(usage, SettingKey.languageUsage)
    }

    func clearLearnedWords() {
        put(nil, SettingKey.languageUsage)
        for language in Language.allCases {
            put(nil, SettingKey.usedWordsPrefix + language.rawValue)
            put(nil, SettingKey.trigramPrefix + language.rawValue)
            put(nil, SettingKey.usagePrefix + language.rawValue)
            put(nil, SettingKey.learnedPrefix + language.rawValue)
            put(nil, SettingKey.correctionsPrefix + language.rawValue)
            put(nil, SettingKey.bigramPrefix + language.rawValue)
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
