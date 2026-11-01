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
    static let deleteSwipedWord = "hunkeys.deleteSwipedWord"
    static let twoThumbSwipe = "hunkeys.twoThumbSwipe"
    static let spaceCommits = "hunkeys.spaceCommits"
    static let multiWordSwipe = "hunkeys.multiWordSwipe"
    static let flickUpCapital = "hunkeys.flickUpCapital"
    static let flickDownAccent = "hunkeys.flickDownAccent"
    // Hitboxes
    static let hitboxSize = "hunkeys.hitboxSize"
    static let adaptiveHitboxes = "hunkeys.adaptiveHitboxes"
    static let adaptiveGrow = "hunkeys.adaptiveGrow"
    static let adaptiveShrink = "hunkeys.adaptiveShrink"
    static let adaptiveStrength = "hunkeys.adaptiveStrength"
    static let adaptiveWordStart = "hunkeys.adaptiveWordStart"
    static let hitMap = "hunkeys.hitMap"
    static let hitMapStrength = "hunkeys.hitMapStrength"
    /// language code -> the learned tap offsets (data written by the keyboard; not a preference).
    static let hitMapPrefix = "hunkeys.hitMapData."
    // Layout and look
    static let numberRow = "hunkeys.numberRow"
    static let keyHints = "hunkeys.keyHints"
    static let theme = "hunkeys.theme"
    static let accent = "hunkeys.accent"
    static let accentHex = "hunkeys.accentHex"
    // Keys, haptics and the suggestion bar (the app's Keys, Haptics and Suggestions screens)
    static let keyHeight = "hunkeys.keyHeight"
    static let landscapeSeparate = "hunkeys.landscapeSeparate"
    static let landscapeKeyHeight = "hunkeys.landscapeKeyHeight"
    static let keyboardWidth = "hunkeys.keyboardWidth"
    static let keyGap = "hunkeys.keyGap"
    static let rowGap = "hunkeys.rowGap"
    static let alwaysCapitals = "hunkeys.alwaysCapitals"
    static let letterSize = "hunkeys.letterSize"
    static let hintPosition = "hunkeys.hintPosition"
    static let hintSize = "hunkeys.hintSize"
    static let spaceText = "hunkeys.spaceText"
    static let spaceTextSize = "hunkeys.spaceTextSize"
    static let spaceLanguageCode = "hunkeys.spaceLanguageCode"
    static let hapticSharpness = "hunkeys.hapticSharpness"
    static let cursorStartHaptic = "hunkeys.cursorStartHaptic"
    static let cursorTickHaptic = "hunkeys.cursorTickHaptic"
    static let suggestionStyle = "hunkeys.suggestionStyle"
    static let separatorStyle = "hunkeys.separatorStyle"
    static let suggestionFollowTheme = "hunkeys.suggestionFollowTheme"
    static let suggestionHeight = "hunkeys.suggestionHeight"
    static let suggestionFit = "hunkeys.suggestionFit"
    static let suggestionScroll = "hunkeys.suggestionScroll"
    static let suggestionDelay = "hunkeys.suggestionDelay"
    static let keyRoundness = "hunkeys.keyRoundness"
    // Data
    static let language = "hunkeys.language"
    static let enabledLanguages = "hunkeys.enabledLanguages"
    static let recentEmoji = "hunkeys.recentEmoji"
    static let shortcuts = "hunkeys.shortcuts"
    /// Key style (the Keys screen): "auto" follows the theme.
    static let keySurface = "hunkeys.keySurface"
    static let keyBorderStyle = "hunkeys.keyBorderStyle"
    static let keyGlow = "hunkeys.keyGlow"
    /// The keys' typeface (KeyFont).
    static let keyFont = "hunkeys.keyFont"
    /// The learned key-offset model (data written by the keyboard; not a preference).
    static let touchModel = "hunkeys.touchModel"
    static let learnedPrefix = "hunkeys.learned."
    /// "typed\tmeant" -> how often the user deleted the typed word and wrote the meant one in its place.
    static let correctionsPrefix = "hunkeys.corrections."
    /// Bumped whenever the app changes what the keyboard learned, so a running keyboard reloads it.
    static let personalRevision = "hunkeys.personalRevision"
    static let bigramPrefix = "hunkeys.bigrams."
    static let trigramPrefix = "hunkeys.trigrams."
    static let usagePrefix = "hunkeys.learnedDays."
    static let usedWordsPrefix = "hunkeys.usedWords."
    /// language code -> how much of what the user writes is in it (recent words count most).
    static let languageUsage = "hunkeys.languageUsage"
    // Written by the keyboard so the app can show its status
    static let lastSeen = "hunkeys.status.lastSeen"
    static let fullAccess = "hunkeys.status.fullAccess"

    /// Everything "Reset settings" puts back to its default (data like shortcuts is left alone).
    static let preferenceKeys: [String] = [
        holdDelay, vibration, clickSound, keyPopups, swipe, suggestions, emojiSuggestions,
        autoCapitalize, doubleSpacePeriod, autoCorrect, cursorControl, deleteSwipe, numberRow, keyHints,
        theme, accent, accentHex, keyRoundness, enabledLanguages, keySurface, keyBorderStyle, keyGlow, keyFont,
        keyHeight, landscapeSeparate, landscapeKeyHeight, keyboardWidth, keyGap, rowGap, alwaysCapitals, letterSize, hintPosition, hintSize, spaceText, spaceTextSize, spaceLanguageCode, hapticSharpness, cursorStartHaptic, cursorTickHaptic, suggestionStyle, separatorStyle, suggestionFollowTheme, suggestionHeight, suggestionFit, suggestionScroll, suggestionDelay,
        deleteSwipedWord, twoThumbSwipe, spaceCommits, multiWordSwipe, flickUpCapital, flickDownAccent,
        hitboxSize, adaptiveHitboxes, adaptiveGrow, adaptiveShrink, adaptiveStrength, adaptiveWordStart,
        hitMap, hitMapStrength
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
    static let deleteSwipedWord = true
    static let twoThumbSwipe = true
    static let spaceCommits = true
    /// Off until tried: a phrase reading only wins clearly, but a single word is the safer default.
    static let multiWordSwipe = false
    static let flickUpCapital = false
    static let flickDownAccent = false
    static let hitboxSize = 1.0
    static let adaptiveHitboxes = true
    static let adaptiveGrow = 0.35
    static let adaptiveShrink = 0.20
    static let adaptiveStrength = 0.65
    static let adaptiveWordStart = true
    static let hitMap = true
    static let hitMapStrength = 0.7
    static let numberRow = false
    static let keyHints = true
    static let theme = "native"
    static let accent = "blue"
    static let accentHex = ""
    /// Flat, sheen or raised keys; "auto": raised on the colour themes, flat on the others.
    static let keySurface = "auto"
    /// None, thin, bold or accent outlines; "auto": thin on every theme but Native.
    static let keyBorderStyle = "auto"
    /// Off, soft or strong accent glow around the keys.
    static let keyGlow = "off"
    static let keyFont = "system"
    static let keyHeight: Double = 45.0
    static let landscapeSeparate: Bool = false
    static let landscapeKeyHeight: Double = 30.0
    static let keyboardWidth: Double = 1.0
    static let keyGap: Double = 6.0
    static let rowGap: Double = 11.0
    static let alwaysCapitals: Bool = false
    static let letterSize: Double = 1.0
    static let hintPosition: String = "topRight"
    static let hintSize: Double = 1.0
    static let spaceText: String = ""
    static let spaceTextSize: Double = 16.0
    static let spaceLanguageCode: Bool = false
    static let hapticSharpness: Double = 1.0
    static let cursorStartHaptic: Bool = true
    static let cursorTickHaptic: Bool = true
    static let suggestionStyle: String = "separators"
    static let separatorStyle: String = "solid"
    static let suggestionFollowTheme: Bool = true
    static let suggestionHeight: Double = 44.0
    static let suggestionFit: Bool = false
    static let suggestionScroll: Bool = false
    static let suggestionDelay: Double = 0.06
    static let keyRoundness = 0.26
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
            SettingKey.deleteSwipedWord: SettingDefault.deleteSwipedWord,
            SettingKey.twoThumbSwipe: SettingDefault.twoThumbSwipe,
            SettingKey.spaceCommits: SettingDefault.spaceCommits,
            SettingKey.multiWordSwipe: SettingDefault.multiWordSwipe,
            SettingKey.flickUpCapital: SettingDefault.flickUpCapital,
            SettingKey.flickDownAccent: SettingDefault.flickDownAccent,
            SettingKey.hitboxSize: SettingDefault.hitboxSize,
            SettingKey.adaptiveHitboxes: SettingDefault.adaptiveHitboxes,
            SettingKey.adaptiveGrow: SettingDefault.adaptiveGrow,
            SettingKey.adaptiveShrink: SettingDefault.adaptiveShrink,
            SettingKey.adaptiveStrength: SettingDefault.adaptiveStrength,
            SettingKey.adaptiveWordStart: SettingDefault.adaptiveWordStart,
            SettingKey.hitMap: SettingDefault.hitMap,
            SettingKey.hitMapStrength: SettingDefault.hitMapStrength,
            SettingKey.numberRow: SettingDefault.numberRow,
            SettingKey.keyHints: SettingDefault.keyHints,
            SettingKey.theme: SettingDefault.theme,
            SettingKey.enabledLanguages: SettingDefault.enabledLanguages,
            SettingKey.accent: SettingDefault.accent,
            SettingKey.accentHex: SettingDefault.accentHex,
            SettingKey.keySurface: SettingDefault.keySurface,
            SettingKey.keyBorderStyle: SettingDefault.keyBorderStyle,
            SettingKey.keyGlow: SettingDefault.keyGlow,
            SettingKey.keyFont: SettingDefault.keyFont,
            SettingKey.keyHeight: SettingDefault.keyHeight,
            SettingKey.landscapeSeparate: SettingDefault.landscapeSeparate,
            SettingKey.landscapeKeyHeight: SettingDefault.landscapeKeyHeight,
            SettingKey.keyboardWidth: SettingDefault.keyboardWidth,
            SettingKey.keyGap: SettingDefault.keyGap,
            SettingKey.rowGap: SettingDefault.rowGap,
            SettingKey.alwaysCapitals: SettingDefault.alwaysCapitals,
            SettingKey.letterSize: SettingDefault.letterSize,
            SettingKey.hintPosition: SettingDefault.hintPosition,
            SettingKey.hintSize: SettingDefault.hintSize,
            SettingKey.spaceText: SettingDefault.spaceText,
            SettingKey.spaceTextSize: SettingDefault.spaceTextSize,
            SettingKey.spaceLanguageCode: SettingDefault.spaceLanguageCode,
            SettingKey.hapticSharpness: SettingDefault.hapticSharpness,
            SettingKey.cursorStartHaptic: SettingDefault.cursorStartHaptic,
            SettingKey.cursorTickHaptic: SettingDefault.cursorTickHaptic,
            SettingKey.suggestionStyle: SettingDefault.suggestionStyle,
            SettingKey.separatorStyle: SettingDefault.separatorStyle,
            SettingKey.suggestionFollowTheme: SettingDefault.suggestionFollowTheme,
            SettingKey.suggestionHeight: SettingDefault.suggestionHeight,
            SettingKey.suggestionFit: SettingDefault.suggestionFit,
            SettingKey.suggestionScroll: SettingDefault.suggestionScroll,
            SettingKey.suggestionDelay: SettingDefault.suggestionDelay,
            SettingKey.keyRoundness: SettingDefault.keyRoundness,
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

    var keySurface: String { return readString(SettingKey.keySurface) ?? SettingDefault.keySurface }
    var keyBorderStyle: String { return readString(SettingKey.keyBorderStyle) ?? SettingDefault.keyBorderStyle }
    var keyGlow: String { return readString(SettingKey.keyGlow) ?? SettingDefault.keyGlow }
    var keyFont: String { return readString(SettingKey.keyFont) ?? SettingDefault.keyFont }

    // MARK: Swipe and flick gestures

    var deleteSwipedWord: Bool { return readBool(SettingKey.deleteSwipedWord) }
    var twoThumbSwipe: Bool { return readBool(SettingKey.twoThumbSwipe) }
    var spaceCommits: Bool { return readBool(SettingKey.spaceCommits) }
    var multiWordSwipe: Bool { return readBool(SettingKey.multiWordSwipe) }
    var flickUpCapital: Bool { return readBool(SettingKey.flickUpCapital) }
    var flickDownAccent: Bool { return readBool(SettingKey.flickDownAccent) }

    // MARK: Hitboxes

    static let hitboxSizeRange: ClosedRange<Double> = 0.80...1.30
    static let adaptiveGrowRange: ClosedRange<Double> = 0...0.60
    static let adaptiveShrinkRange: ClosedRange<Double> = 0...0.40

    /// Letter-key touch areas compared with the other keys: < 1 lets shift, delete and space take more of the
    /// edges, > 1 gives them to the letters.
    var hitboxSize: Double { return clamp(readDouble(SettingKey.hitboxSize), Settings.hitboxSizeRange) }
    var adaptiveHitboxes: Bool { return readBool(SettingKey.adaptiveHitboxes) }
    var adaptiveGrow: Double { return clamp(readDouble(SettingKey.adaptiveGrow), Settings.adaptiveGrowRange) }
    var adaptiveShrink: Double { return clamp(readDouble(SettingKey.adaptiveShrink), Settings.adaptiveShrinkRange) }
    var adaptiveStrength: Double { return clamp(readDouble(SettingKey.adaptiveStrength), 0...1) }
    var adaptiveWordStart: Bool { return readBool(SettingKey.adaptiveWordStart) }
    var hitMap: Bool { return readBool(SettingKey.hitMap) }
    var hitMapStrength: Double { return clamp(readDouble(SettingKey.hitMapStrength), 0...1) }

    /// The hit map of a language: letter -> [taps, mean x offset, mean y offset] (offsets in key widths/heights,
    /// from the key's centre to where the user actually taps it).
    func hitMapData(for languageCode: String) -> [String: [Double]] {
        return value(SettingKey.hitMapPrefix + languageCode) as? [String: [Double]] ?? [:]
    }

    func setHitMapData(_ data: [String: [Double]], for languageCode: String) {
        put(data.isEmpty ? nil : data, SettingKey.hitMapPrefix + languageCode)
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

    /// 0 = square keys ... 1 = fully round (pill) keys.
    var keyRoundness: Double {
        get { return clamp(readDouble(SettingKey.keyRoundness), 0...1) }
        set { put(clamp(newValue, 0...1), SettingKey.keyRoundness) }
    }

    // MARK: Keys, haptics and the suggestion bar

    /// Drawn height of a key in portrait (pt); the keyboard grows or shrinks to fit. In landscape the keys keep
    /// the same share unless `landscapeSeparate` gives them their own `landscapeKeyHeight`.
    static let keyHeightRange: ClosedRange<Double> = 34...60
    static let landscapeKeyHeightRange: ClosedRange<Double> = 24...44
    static let keyboardWidthRange: ClosedRange<Double> = 0.80...1.0
    static let keyGapRange: ClosedRange<Double> = 2...14
    static let rowGapRange: ClosedRange<Double> = 4...20
    static let letterSizeRange: ClosedRange<Double> = 0.80...1.30
    static let hintSizeRange: ClosedRange<Double> = 0.70...1.50
    static let spaceTextSizeRange: ClosedRange<Double> = 11...22
    static let hapticSharpnessRange: ClosedRange<Double> = 0...1
    static let suggestionHeightRange: ClosedRange<Double> = 32...56
    static let suggestionDelayRange: ClosedRange<Double> = 0...0.30

    var keyHeight: Double { return clamp(readDouble(SettingKey.keyHeight), Settings.keyHeightRange) }
    var landscapeSeparate: Bool { return readBool(SettingKey.landscapeSeparate) }
    var landscapeKeyHeight: Double { return clamp(readDouble(SettingKey.landscapeKeyHeight), Settings.landscapeKeyHeightRange) }
    var keyboardWidth: Double { return clamp(readDouble(SettingKey.keyboardWidth), Settings.keyboardWidthRange) }
    var keyGap: Double { return clamp(readDouble(SettingKey.keyGap), Settings.keyGapRange) }
    var rowGap: Double { return clamp(readDouble(SettingKey.rowGap), Settings.rowGapRange) }
    var alwaysCapitals: Bool { return readBool(SettingKey.alwaysCapitals) }
    var letterSize: Double { return clamp(readDouble(SettingKey.letterSize), Settings.letterSizeRange) }
    var hintPosition: String { return readString(SettingKey.hintPosition) ?? SettingDefault.hintPosition }
    var hintSize: Double { return clamp(readDouble(SettingKey.hintSize), Settings.hintSizeRange) }
    var spaceText: String { return readString(SettingKey.spaceText) ?? SettingDefault.spaceText }
    var spaceTextSize: Double { return clamp(readDouble(SettingKey.spaceTextSize), Settings.spaceTextSizeRange) }
    var spaceLanguageCode: Bool { return readBool(SettingKey.spaceLanguageCode) }
    var hapticSharpness: Double { return clamp(readDouble(SettingKey.hapticSharpness), Settings.hapticSharpnessRange) }
    var cursorStartHaptic: Bool { return readBool(SettingKey.cursorStartHaptic) }
    var cursorTickHaptic: Bool { return readBool(SettingKey.cursorTickHaptic) }
    var suggestionStyle: String { return readString(SettingKey.suggestionStyle) ?? SettingDefault.suggestionStyle }
    var separatorStyle: String { return readString(SettingKey.separatorStyle) ?? SettingDefault.separatorStyle }
    var suggestionFollowTheme: Bool { return readBool(SettingKey.suggestionFollowTheme) }
    var suggestionHeight: Double { return clamp(readDouble(SettingKey.suggestionHeight), Settings.suggestionHeightRange) }
    var suggestionFit: Bool { return readBool(SettingKey.suggestionFit) }
    var suggestionScroll: Bool { return readBool(SettingKey.suggestionScroll) }
    var suggestionDelay: Double { return clamp(readDouble(SettingKey.suggestionDelay), Settings.suggestionDelayRange) }

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

    var personalRevision: Int {
        return value(SettingKey.personalRevision) as? Int ?? 0
    }

    /// The words the keyboard has learned (used at least `learnAfter` times), alphabetically.
    func learnedWordList(for languageCode: String, learnAfter: Int = 2) -> [String] {
        return learnedWords(for: languageCode).filter { $0.value >= learnAfter }.keys
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Removes one learned word (from the app's list); the keyboard picks the change up when it opens.
    func removeLearnedWord(_ word: String, for languageCode: String) {
        var words = learnedWords(for: languageCode)
        words.removeValue(forKey: word)
        setLearnedWords(words, for: languageCode)
        var corrections = self.corrections(for: languageCode)
        for key in corrections.keys where key.hasSuffix("\t" + word) { corrections.removeValue(forKey: key) }
        setCorrections(corrections, for: languageCode)
        bumpPersonalRevision()
    }

    func bumpPersonalRevision() {
        put(personalRevision + 1, SettingKey.personalRevision)
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
        bumpPersonalRevision()
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
