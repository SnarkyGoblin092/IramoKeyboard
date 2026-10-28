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
    static var cursorControl = SettingDefault.cursorControl
    static var deleteSwipe = SettingDefault.deleteSwipe
    static var numberRow = SettingDefault.numberRow
    static var keyHints = SettingDefault.keyHints
    static var heightScale = SettingDefault.keyboardHeight
    static var touchLearning = true

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
        cursorControl = s.cursorControl
        deleteSwipe = s.deleteSwipe
        numberRow = s.numberRow
        keyHints = s.keyHints
        heightScale = s.keyboardHeightScale
        touchLearning = s.touchLearning
        if let stored = SharedStore.defaults.object(forKey: keyRoundnessKey) as? Double {
            keyRoundness = min(max(stored, 0), 1)
        } else {
            keyRoundness = keyRoundnessDefault
        }
    }
}
