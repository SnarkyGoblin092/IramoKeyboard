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
    static let splitKeyboard = "hunkeys.splitKeyboard"
    static let oneHanded = "hunkeys.oneHanded"
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
    static let suggestionTransition = "hunkeys.suggestionTransition"
    static let suggestionTransitionDuration = "hunkeys.suggestionTransitionDuration"
    static let swipeTrailLength = "hunkeys.swipeTrailLength"
    // Emoji picker (the app's Emoji screen)
    static let emojiShowRecents = "hunkeys.emojiShowRecents"
    static let emojiRecentOrder = "hunkeys.emojiRecentOrder"
    static let emojiRecentLimit = "hunkeys.emojiRecentLimit"
    static let emojiSpaceAfter = "hunkeys.emojiSpaceAfter"
    static let emojiScroll = "hunkeys.emojiScroll"
    static let emojiSwipeTabs = "hunkeys.emojiSwipeTabs"
    static let emojiRows = "hunkeys.emojiRows"
    static let emojiSize = "hunkeys.emojiSize"
    static let emojiSpacing = "hunkeys.emojiSpacing"
    static let emojiSearchPosition = "hunkeys.emojiSearchPosition"
    static let emojiTabsPosition = "hunkeys.emojiTabsPosition"
    static let emojiTabStyle = "hunkeys.emojiTabStyle"
    static let emojiBackspaceKey = "hunkeys.emojiBackspaceKey"
    static let emojiCategoryOrder = "hunkeys.emojiCategoryOrder"
    static let emojiHiddenCategories = "hunkeys.emojiHiddenCategories"
    static let emojiSkinTone = "hunkeys.emojiSkinTone"
    static let emojiHoldDelay = "hunkeys.emojiHoldDelay"
    /// Emoji -> how often it was picked (data for the "Most used" order; not a preference).
    static let emojiUseCounts = "hunkeys.emojiUseCounts"
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
    /// Before learned words were shared by every language: one list per language (moved into `learnedWords`).
    static let learnedPrefix = "hunkeys.learned."
    /// The words the keyboard learned, word -> count, one list for every language.
    static let learnedWords = "hunkeys.learnedWords"
    /// Learned word -> last day it was used (days since 1970).
    static let learnedWordDays = "hunkeys.learnedWordDays"
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
    /// Chinese typed by sound, per language: "spelling|word" -> how often the user picked that word for those letters.
    static let phoneticPicksPrefix = "hunkeys.phoneticPicks."
    // Written by the keyboard so the app can show its status
    static let lastSeen = "hunkeys.status.lastSeen"
    static let fullAccess = "hunkeys.status.fullAccess"

    /// Everything "Reset settings" puts back to its default (data like shortcuts is left alone).
    static let preferenceKeys: [String] = [
        holdDelay, vibration, clickSound, keyPopups, swipe, suggestions, emojiSuggestions,
        autoCapitalize, doubleSpacePeriod, autoCorrect, cursorControl, deleteSwipe, numberRow, keyHints,
        theme, accent, accentHex, keyRoundness, enabledLanguages, keySurface, keyBorderStyle, keyGlow, keyFont,
        keyHeight, landscapeSeparate, landscapeKeyHeight, keyboardWidth, keyGap, rowGap, alwaysCapitals, letterSize, hintPosition, hintSize, spaceTextSize, spaceLanguageCode, hapticSharpness, cursorStartHaptic, cursorTickHaptic, suggestionStyle, separatorStyle, suggestionFollowTheme, suggestionHeight, suggestionFit, suggestionScroll, suggestionDelay, suggestionTransition, suggestionTransitionDuration, swipeTrailLength,
        emojiShowRecents, emojiRecentOrder, emojiRecentLimit, emojiSpaceAfter, emojiScroll, emojiSwipeTabs, emojiRows,
        emojiSize, emojiSpacing, emojiSearchPosition, emojiTabsPosition, emojiTabStyle, emojiBackspaceKey,
        emojiCategoryOrder, emojiHiddenCategories, emojiSkinTone, emojiHoldDelay,
        deleteSwipedWord, twoThumbSwipe, spaceCommits, multiWordSwipe, flickUpCapital, flickDownAccent,
        splitKeyboard, oneHanded,
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
    /// iPad: the keys in two halves, one under each thumb.
    static let splitKeyboard = false
    /// A narrower keyboard against one side, for one hand: "off", "left" or "right".
    static let oneHanded = "off"
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
    static let suggestionDelay: Double = 0.15
    /// How new words replace the old ones: "instant", "fade", "rise", "slide" or "pop".
    static let suggestionTransition: String = "instant"
    /// How long a switch animation takes, in seconds (the same in the keyboard and the app's preview).
    static let suggestionTransitionDuration: Double = 0.25
    /// How long the swipe line stays behind the finger, in points of path (the older part fades out).
    static let swipeTrailLength: Double = 220
    // Emoji picker: the defaults are the system emoji keyboard's look.
    static let emojiShowRecents = true
    /// "recent" (last picked first) or "used" (most picked first).
    static let emojiRecentOrder = "recent"
    static let emojiRecentLimit: Double = 32
    static let emojiSpaceAfter = false
    /// "horizontal" (one strip, like the system's) or "vertical".
    static let emojiScroll = "horizontal"
    static let emojiSwipeTabs = false
    static let emojiRows: Double = 4
    /// The emoji's size, as a share of its cell.
    static let emojiSize: Double = 0.79
    /// Extra points between neighbouring emoji.
    static let emojiSpacing: Double = 0
    /// "top", "bottom" or "hidden".
    static let emojiSearchPosition = "top"
    static let emojiTabsPosition = "bottom"
    /// "symbols" (outline icons) or "emoji".
    static let emojiTabStyle = "symbols"
    static let emojiBackspaceKey = true
    /// The tabs' order ("recent" and the category keys); empty: the system's order.
    static let emojiCategoryOrder: [String] = []
    static let emojiHiddenCategories: [String] = []
    /// 0: the yellow default, 1...5: light ... dark.
    static let emojiSkinTone: Double = 0
    /// How long to hold an emoji for its skin tones, in seconds.
    static let emojiHoldDelay: Double = 0.30
    static let keyRoundness = 0.26
    static let language = "en"
    static let enabledLanguages = ["en"]
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
            SettingKey.splitKeyboard: SettingDefault.splitKeyboard,
            SettingKey.oneHanded: SettingDefault.oneHanded,
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
            SettingKey.suggestionTransition: SettingDefault.suggestionTransition,
            SettingKey.suggestionTransitionDuration: SettingDefault.suggestionTransitionDuration,
            SettingKey.swipeTrailLength: SettingDefault.swipeTrailLength,
            SettingKey.emojiShowRecents: SettingDefault.emojiShowRecents,
            SettingKey.emojiRecentOrder: SettingDefault.emojiRecentOrder,
            SettingKey.emojiRecentLimit: SettingDefault.emojiRecentLimit,
            SettingKey.emojiSpaceAfter: SettingDefault.emojiSpaceAfter,
            SettingKey.emojiScroll: SettingDefault.emojiScroll,
            SettingKey.emojiSwipeTabs: SettingDefault.emojiSwipeTabs,
            SettingKey.emojiRows: SettingDefault.emojiRows,
            SettingKey.emojiSize: SettingDefault.emojiSize,
            SettingKey.emojiSpacing: SettingDefault.emojiSpacing,
            SettingKey.emojiSearchPosition: SettingDefault.emojiSearchPosition,
            SettingKey.emojiTabsPosition: SettingDefault.emojiTabsPosition,
            SettingKey.emojiTabStyle: SettingDefault.emojiTabStyle,
            SettingKey.emojiBackspaceKey: SettingDefault.emojiBackspaceKey,
            SettingKey.emojiCategoryOrder: SettingDefault.emojiCategoryOrder,
            SettingKey.emojiHiddenCategories: SettingDefault.emojiHiddenCategories,
            SettingKey.emojiSkinTone: SettingDefault.emojiSkinTone,
            SettingKey.emojiHoldDelay: SettingDefault.emojiHoldDelay,
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
    var splitKeyboard: Bool { return readBool(SettingKey.splitKeyboard) }
    var oneHanded: String { return readString(SettingKey.oneHanded) ?? SettingDefault.oneHanded }
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
    static let suggestionDelayRange: ClosedRange<Double> = 0.05...0.50
    static let suggestionTransitionDurationRange: ClosedRange<Double> = 0.10...0.50
    static let swipeTrailLengthRange: ClosedRange<Double> = 60...600
    static let emojiRecentLimitRange: ClosedRange<Double> = 8...64
    static let emojiRowsRange: ClosedRange<Double> = 3...7
    static let emojiSizeRange: ClosedRange<Double> = 0.40...1.00
    static let emojiSpacingRange: ClosedRange<Double> = 0...12
    static let emojiSkinToneRange: ClosedRange<Double> = 0...5
    static let emojiHoldDelayRange: ClosedRange<Double> = 0.15...0.80

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
    var suggestionTransitionDuration: Double { return clamp(readDouble(SettingKey.suggestionTransitionDuration), Settings.suggestionTransitionDurationRange) }
    var suggestionTransition: String { return readString(SettingKey.suggestionTransition) ?? SettingDefault.suggestionTransition }
    var swipeTrailLength: Double { return clamp(readDouble(SettingKey.swipeTrailLength), Settings.swipeTrailLengthRange) }

    // MARK: Emoji picker

    var emojiShowRecents: Bool { return readBool(SettingKey.emojiShowRecents) }
    var emojiRecentOrder: String { return readString(SettingKey.emojiRecentOrder) ?? SettingDefault.emojiRecentOrder }
    var emojiRecentLimit: Int { return Int(clamp(readDouble(SettingKey.emojiRecentLimit), Settings.emojiRecentLimitRange).rounded()) }
    var emojiSpaceAfter: Bool { return readBool(SettingKey.emojiSpaceAfter) }
    var emojiScroll: String { return readString(SettingKey.emojiScroll) ?? SettingDefault.emojiScroll }
    var emojiSwipeTabs: Bool { return readBool(SettingKey.emojiSwipeTabs) }
    var emojiRows: Int { return Int(clamp(readDouble(SettingKey.emojiRows), Settings.emojiRowsRange).rounded()) }
    var emojiSize: Double { return clamp(readDouble(SettingKey.emojiSize), Settings.emojiSizeRange) }
    var emojiSpacing: Double { return clamp(readDouble(SettingKey.emojiSpacing), Settings.emojiSpacingRange) }
    var emojiSearchPosition: String { return readString(SettingKey.emojiSearchPosition) ?? SettingDefault.emojiSearchPosition }
    var emojiTabsPosition: String { return readString(SettingKey.emojiTabsPosition) ?? SettingDefault.emojiTabsPosition }
    var emojiTabStyle: String { return readString(SettingKey.emojiTabStyle) ?? SettingDefault.emojiTabStyle }
    var emojiBackspaceKey: Bool { return readBool(SettingKey.emojiBackspaceKey) }
    var emojiCategoryOrder: [String] { return readStringArray(SettingKey.emojiCategoryOrder) ?? [] }
    var emojiHiddenCategories: [String] { return readStringArray(SettingKey.emojiHiddenCategories) ?? [] }
    var emojiSkinTone: Int { return Int(clamp(readDouble(SettingKey.emojiSkinTone), Settings.emojiSkinToneRange).rounded()) }
    var emojiHoldDelay: Double { return clamp(readDouble(SettingKey.emojiHoldDelay), Settings.emojiHoldDelayRange) }

    // MARK: Data

    var languageCode: String {
        get { return readString(SettingKey.language) ?? SettingDefault.language }
        set { put(newValue, SettingKey.language) }
    }

    var recentEmoji: [String] {
        get { return readStringArray(SettingKey.recentEmoji) ?? [] }
        set { put(newValue, SettingKey.recentEmoji) }
    }

    /// The words the keyboard learned, shared by every language. The per-language lists of earlier versions are
    /// merged into it the first time it is read.
    func learnedWords() -> [String: Int] {
        if let words = value(SettingKey.learnedWords) as? [String: Int] { return words }
        var merged: [String: Int] = [:]
        var days: [String: Int] = [:]
        for language in Language.allCases {
            let code = language.rawValue
            guard let words = value(SettingKey.learnedPrefix + code) as? [String: Int] else { continue }
            let usage = learnedUsage(for: code)
            for (word, count) in words {
                merged[word, default: 0] += count
                if let day = usage[word] { days[word] = max(days[word] ?? 0, day) }
            }
            put(nil, SettingKey.learnedPrefix + code)
        }
        put(merged, SettingKey.learnedWords)
        put(days, SettingKey.learnedWordDays)
        return merged
    }

    func setLearnedWords(_ words: [String: Int]) {
        put(words, SettingKey.learnedWords)
    }

    func learnedWordDays() -> [String: Int] {
        return value(SettingKey.learnedWordDays) as? [String: Int] ?? [:]
    }

    func setLearnedWordDays(_ days: [String: Int]) {
        put(days, SettingKey.learnedWordDays)
    }

    var personalRevision: Int {
        return value(SettingKey.personalRevision) as? Int ?? 0
    }

    /// The words the keyboard has learned (used at least `learnAfter` times), alphabetically.
    func learnedWordList(learnAfter: Int = 2) -> [String] {
        return learnedWords().filter { $0.value >= learnAfter }.keys
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Removes one learned word (from the app's list), in every language; the keyboard picks the change up when it
    /// opens.
    func removeLearnedWord(_ word: String) {
        var words = learnedWords()
        words.removeValue(forKey: word)
        setLearnedWords(words)
        var days = learnedWordDays()
        days.removeValue(forKey: word)
        setLearnedWordDays(days)
        for language in Language.allCases {
            var corrections = self.corrections(for: language.rawValue)
            let before = corrections.count
            for key in corrections.keys where key.hasSuffix("\t" + word) { corrections.removeValue(forKey: key) }
            if corrections.count != before { setCorrections(corrections, for: language.rawValue) }
        }
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
        put([String: Int](), SettingKey.learnedWords)   // empty rather than missing: nothing left to merge
        put(nil, SettingKey.learnedWordDays)
        for language in Language.allCases {
            put(nil, SettingKey.usedWordsPrefix + language.rawValue)
            put(nil, SettingKey.trigramPrefix + language.rawValue)
            put(nil, SettingKey.usagePrefix + language.rawValue)
            put(nil, SettingKey.learnedPrefix + language.rawValue)
            put(nil, SettingKey.phoneticPicksPrefix + language.rawValue)
            put(nil, SettingKey.correctionsPrefix + language.rawValue)
            put(nil, SettingKey.bigramPrefix + language.rawValue)
        }
        bumpPersonalRevision()
    }

    func clearRecentEmoji() {
        put(nil, SettingKey.recentEmoji)
        put(nil, SettingKey.emojiUseCounts)
    }

    /// How often each recent emoji was picked.
    var emojiUseCounts: [String: Int] {
        get { return value(SettingKey.emojiUseCounts) as? [String: Int] ?? [:] }
        set { put(newValue, SettingKey.emojiUseCounts) }
    }

    /// Notes a picked emoji: first among the recents and counted once more, keeping only as many as the user
    /// chose.
    func rememberEmoji(_ emoji: String) {
        var recents = recentEmoji.filter { $0 != emoji }
        recents.insert(emoji, at: 0)
        recents = Array(recents.prefix(emojiRecentLimit))
        var counts = emojiUseCounts
        counts[emoji, default: 0] += 1
        let kept = Set(recents)
        counts = counts.filter { kept.contains($0.key) }
        recentEmoji = recents
        emojiUseCounts = counts
    }

    /// The recents in the chosen order (Most recent; or Most used, the latest first among equals), as many as
    /// the user keeps.
    func orderedRecentEmoji() -> [String] {
        let recents = Array(recentEmoji.prefix(emojiRecentLimit))
        guard emojiRecentOrder == "used" else { return recents }
        let counts = emojiUseCounts
        return recents.enumerated()
            .sorted { a, b in
                let ca = counts[a.element] ?? 0, cb = counts[b.element] ?? 0
                return ca != cb ? ca > cb : a.offset < b.offset
            }
            .map { $0.element }
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
