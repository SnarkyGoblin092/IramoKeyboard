import UIKit

/// A cached copy of the settings that are read while typing.
///
/// Reading `UserDefaults` for every key press is wasted work, so the keyboard refreshes this snapshot
/// when it appears and whenever it rebuilds, and the touch / typing paths read plain properties.
final class Prefs {
    static var holdDelay = SettingDefault.holdDelay
    static var vibration = SettingDefault.vibration
    static var clickSound = SettingDefault.clickSound
    static var clickSoundStyle = KeySound.tock
    static var keyPopups = SettingDefault.keyPopups
    static var swipe = SettingDefault.swipe
    static var suggestions = SettingDefault.suggestions
    static var emojiSuggestions = SettingDefault.emojiSuggestions
    static var autoCapitalize = SettingDefault.autoCapitalize
    static var doubleSpacePeriod = SettingDefault.doubleSpacePeriod
    static var autoCorrect = SettingDefault.autoCorrect
    static var cursorControl = SettingDefault.cursorControl
    static var swipeDownHide = SettingDefault.swipeDownHide
    static var deleteSwipe = SettingDefault.deleteSwipe
    static var numberRow = SettingDefault.numberRow
    static var keyHints = SettingDefault.keyHints
    static var extraKeys: [String] = []
    static var extraKeysLeft: [String] = []
    static var commaKey = SettingDefault.commaKey
    static var periodKey = SettingDefault.periodKey
    static var emojiKey = SettingDefault.emojiKey
    static var commaHold: [String] = []
    static var periodHold: [String] = []
    static var keyHeight = SettingDefault.keyHeight
    static var landscapeSeparate = SettingDefault.landscapeSeparate
    static var landscapeKeyHeight = SettingDefault.landscapeKeyHeight
    static var keyboardWidth = SettingDefault.keyboardWidth
    static var keyGap = SettingDefault.keyGap
    static var rowGap = SettingDefault.rowGap
    static var alwaysCapitals = SettingDefault.alwaysCapitals
    static var letterSize = SettingDefault.letterSize
    static var hintPosition = SettingDefault.hintPosition
    static var hintSize = SettingDefault.hintSize
    static var spaceTextSize = SettingDefault.spaceTextSize
    static var spaceLanguageCode = SettingDefault.spaceLanguageCode
    static var hapticSharpness = SettingDefault.hapticSharpness
    static var cursorStartHaptic = SettingDefault.cursorStartHaptic
    static var cursorTickHaptic = SettingDefault.cursorTickHaptic
    static var suggestionStyle = SettingDefault.suggestionStyle
    static var separatorStyle = SettingDefault.separatorStyle
    static var suggestionFollowTheme = SettingDefault.suggestionFollowTheme
    static var suggestionHeight = SettingDefault.suggestionHeight
    static var suggestionFit = SettingDefault.suggestionFit
    static var suggestionScroll = SettingDefault.suggestionScroll
    static var suggestionScrollThree = SettingDefault.suggestionScrollThree
    static var suggestionDelay = SettingDefault.suggestionDelay
    static var suggestionTransition = SettingDefault.suggestionTransition
    static var suggestionTransitionDuration = SettingDefault.suggestionTransitionDuration
    static var swipeTrailLength = SettingDefault.swipeTrailLength
    static var keySurface = SettingDefault.keySurface
    static var keyBorderStyle = SettingDefault.keyBorderStyle
    static var keyGlow = SettingDefault.keyGlow
    static var effects = EffectsConfig()
    static var keyFont = SettingDefault.keyFont
    static var deleteSwipedWord = SettingDefault.deleteSwipedWord
    static var deleteRepeatDelay = SettingDefault.deleteRepeatDelay
    static var twoThumbSwipe = SettingDefault.twoThumbSwipe
    static var spaceCommits = SettingDefault.spaceCommits
    static var multiWordSwipe = SettingDefault.multiWordSwipe
    static var splitKeyboard = SettingDefault.splitKeyboard
    static var oneHanded = SettingDefault.oneHanded
    static var flickUpCapital = SettingDefault.flickUpCapital
    static var flickDownAccent = SettingDefault.flickDownAccent
    static var swipeTrailShown = SettingDefault.swipeTrailShown
    static var swipeTrailWidth = SettingDefault.swipeTrailWidth
    static var swipeTrailOpacity = SettingDefault.swipeTrailOpacity
    static var swipeTrailColor = SettingDefault.swipeTrailColor
    static var swipeTrailStyle = SettingDefault.swipeTrailStyle
    static var spaceSelect = SettingDefault.spaceSelect
    static var cursorSpeed = SettingDefault.cursorSpeed
    static var deleteRepeatInterval = SettingDefault.deleteRepeatInterval
    static var letterLayouts: [String: String] = [:]
    static var customHolds: [String: [String]] = [:]
    static var inlineMath = SettingDefault.inlineMath
    static var unitConversion = SettingDefault.unitConversion
    static var unitTarget = SettingDefault.unitTarget
    static var resultDecimals = Int(SettingDefault.resultDecimals)
    static var smartQuotes = SettingDefault.smartQuotes
    static var spaceAfterPunctuation = SettingDefault.spaceAfterPunctuation
    static var statsEnabled = SettingDefault.statsEnabled

    /// The letter layout picked for a language (its own when none is).
    static func letterLayout(for language: Language) -> LetterLayout {
        return LetterLayout.stored(in: letterLayouts, for: language.rawValue)
    }

    /// 0 = square key corners ... 1 = fully round. Read from the shared defaults directly so this
    /// file works whichever way the Settings class exposes it.
    static let keyRoundnessKey = "hunkeys.keyRoundness"
    static let keyRoundnessDefault = 0.26
    static var keyRoundness = keyRoundnessDefault

    /// Re-reads everything from the shared settings.
    static func refresh() {
        let s = Settings.shared
        holdDelay = s.holdDelay
        vibration = s.vibrationStrength
        clickSound = s.clickSound
        clickSoundStyle = s.clickSoundStyle
        keyPopups = s.keyPopups
        swipe = s.swipeEnabled
        suggestions = s.suggestionsEnabled
        // Emoji suggestions are words in the bar too: none while word suggestions are off.
        emojiSuggestions = s.emojiSuggestionsEnabled && s.suggestionsEnabled
        autoCapitalize = s.autoCapitalize
        doubleSpacePeriod = s.doubleSpacePeriod
        autoCorrect = s.autoCorrect
        cursorControl = s.cursorControl
        swipeDownHide = s.swipeDownHide
        deleteSwipe = s.deleteSwipe
        numberRow = s.numberRow
        keyHints = s.keyHints
        extraKeys = s.extraKeys
        extraKeysLeft = s.extraKeysLeft
        commaKey = s.commaKey
        periodKey = s.periodKey
        emojiKey = s.emojiKey
        commaHold = s.commaHold
        periodHold = s.periodHold
        keyHeight = s.keyHeight
        landscapeSeparate = s.landscapeSeparate
        landscapeKeyHeight = s.landscapeKeyHeight
        keyboardWidth = s.keyboardWidth
        keyGap = s.keyGap
        rowGap = s.rowGap
        alwaysCapitals = s.alwaysCapitals
        letterSize = s.letterSize
        hintPosition = s.hintPosition
        hintSize = s.hintSize
        spaceTextSize = s.spaceTextSize
        spaceLanguageCode = s.spaceLanguageCode
        hapticSharpness = s.hapticSharpness
        cursorStartHaptic = s.cursorStartHaptic
        cursorTickHaptic = s.cursorTickHaptic
        suggestionStyle = s.suggestionStyle
        separatorStyle = s.separatorStyle
        suggestionFollowTheme = s.suggestionFollowTheme
        suggestionHeight = s.suggestionHeight
        suggestionFit = s.suggestionFit
        suggestionScroll = s.suggestionScroll
        suggestionScrollThree = s.suggestionScrollThree
        suggestionDelay = s.suggestionDelay
        suggestionTransition = s.suggestionTransition
        suggestionTransitionDuration = s.suggestionTransitionDuration
        swipeTrailLength = s.swipeTrailLength
        keySurface = s.keySurface
        keyBorderStyle = s.keyBorderStyle
        keyGlow = s.keyGlow
        effects = EffectsConfig.decode(s.effectsJSON)
        keyFont = s.keyFont
        deleteSwipedWord = s.deleteSwipedWord
        deleteRepeatDelay = s.deleteRepeatDelay
        twoThumbSwipe = s.twoThumbSwipe
        spaceCommits = s.spaceCommits
        multiWordSwipe = s.multiWordSwipe
        splitKeyboard = s.splitKeyboard
        oneHanded = s.oneHanded
        flickUpCapital = s.flickUpCapital
        flickDownAccent = s.flickDownAccent
        swipeTrailShown = s.swipeTrailShown
        swipeTrailWidth = s.swipeTrailWidth
        swipeTrailOpacity = s.swipeTrailOpacity
        swipeTrailColor = s.swipeTrailColor
        swipeTrailStyle = s.swipeTrailStyle
        spaceSelect = s.spaceSelect
        cursorSpeed = s.cursorSpeed
        deleteRepeatInterval = s.deleteRepeatInterval
        letterLayouts = s.letterLayouts
        var holds: [String: [String]] = [:]
        for (key, symbols) in s.customHolds {
            let list = Settings.holdSymbols(symbols)
            if !key.isEmpty, !list.isEmpty { holds[key.lowercased()] = list }
        }
        customHolds = holds
        inlineMath = s.inlineMath
        unitConversion = s.unitConversion
        unitTarget = s.unitTarget
        resultDecimals = s.resultDecimals
        smartQuotes = s.smartQuotes
        spaceAfterPunctuation = s.spaceAfterPunctuation
        statsEnabled = s.statsEnabled
        if let stored = SharedStore.defaults.object(forKey: keyRoundnessKey) as? Double {
            keyRoundness = min(max(stored, 0), 1)
        } else {
            keyRoundness = keyRoundnessDefault
        }
    }
}
