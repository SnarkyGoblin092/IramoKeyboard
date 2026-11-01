import UIKit

/// A cached copy of the settings that are read while typing.
///
/// Reading `UserDefaults` for every key press is wasted work, so the keyboard refreshes this snapshot
/// when it appears and whenever it rebuilds, and the touch / typing paths read plain properties.
final class Prefs {
    static var holdDelay = SettingDefault.holdDelay
    static var vibration = SettingDefault.vibration
    static var clickSound = SettingDefault.clickSound
    static var keyPopups = SettingDefault.keyPopups
    static var swipe = SettingDefault.swipe
    static var suggestions = SettingDefault.suggestions
    static var emojiSuggestions = SettingDefault.emojiSuggestions
    static var autoCapitalize = SettingDefault.autoCapitalize
    static var doubleSpacePeriod = SettingDefault.doubleSpacePeriod
    static var autoCorrect = SettingDefault.autoCorrect
    static var cursorControl = SettingDefault.cursorControl
    static var deleteSwipe = SettingDefault.deleteSwipe
    static var numberRow = SettingDefault.numberRow
    static var keyHints = SettingDefault.keyHints
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
    static var spaceText = SettingDefault.spaceText
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
    static var suggestionDelay = SettingDefault.suggestionDelay
    static var keySurface = SettingDefault.keySurface
    static var keyBorderStyle = SettingDefault.keyBorderStyle
    static var keyGlow = SettingDefault.keyGlow
    static var deleteSwipedWord = SettingDefault.deleteSwipedWord
    static var twoThumbSwipe = SettingDefault.twoThumbSwipe
    static var spaceCommits = SettingDefault.spaceCommits
    static var multiWordSwipe = SettingDefault.multiWordSwipe
    static var flickUpCapital = SettingDefault.flickUpCapital
    static var flickDownAccent = SettingDefault.flickDownAccent
    static var hitboxSize = SettingDefault.hitboxSize
    static var adaptiveHitboxes = SettingDefault.adaptiveHitboxes
    static var adaptiveGrow = SettingDefault.adaptiveGrow
    static var adaptiveShrink = SettingDefault.adaptiveShrink
    static var adaptiveStrength = SettingDefault.adaptiveStrength
    static var adaptiveWordStart = SettingDefault.adaptiveWordStart
    static var hitMap = SettingDefault.hitMap
    static var hitMapStrength = SettingDefault.hitMapStrength

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
        keyPopups = s.keyPopups
        swipe = s.swipeEnabled
        suggestions = s.suggestionsEnabled
        emojiSuggestions = s.emojiSuggestionsEnabled
        autoCapitalize = s.autoCapitalize
        doubleSpacePeriod = s.doubleSpacePeriod
        autoCorrect = s.autoCorrect
        cursorControl = s.cursorControl
        deleteSwipe = s.deleteSwipe
        numberRow = s.numberRow
        keyHints = s.keyHints
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
        spaceText = s.spaceText
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
        suggestionDelay = s.suggestionDelay
        keySurface = s.keySurface
        keyBorderStyle = s.keyBorderStyle
        keyGlow = s.keyGlow
        deleteSwipedWord = s.deleteSwipedWord
        twoThumbSwipe = s.twoThumbSwipe
        spaceCommits = s.spaceCommits
        multiWordSwipe = s.multiWordSwipe
        flickUpCapital = s.flickUpCapital
        flickDownAccent = s.flickDownAccent
        hitboxSize = s.hitboxSize
        adaptiveHitboxes = s.adaptiveHitboxes
        adaptiveGrow = s.adaptiveGrow
        adaptiveShrink = s.adaptiveShrink
        adaptiveStrength = s.adaptiveStrength
        adaptiveWordStart = s.adaptiveWordStart
        hitMap = s.hitMap
        hitMapStrength = s.hitMapStrength
        if let stored = SharedStore.defaults.object(forKey: keyRoundnessKey) as? Double {
            keyRoundness = min(max(stored, 0), 1)
        } else {
            keyRoundness = keyRoundnessDefault
        }
    }
}
