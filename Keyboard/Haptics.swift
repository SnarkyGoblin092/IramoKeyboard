import UIKit

/// Key-press vibration with adjustable strength, plus the optional system key-click sound.
///
/// iOS only lets keyboard extensions use the haptic engine when the user has switched on
/// "Allow Full Access" for the keyboard (Settings > General > Keyboard > Keyboards > HunKeys).
final class Haptics {
    static let shared = Haptics()

    private let pressGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let tickGenerator = UIImpactFeedbackGenerator(style: .soft)
    private var lastTick = Date.distantPast

    private init() {}

    func prepare() {
        pressGenerator.prepare()
        tickGenerator.prepare()
    }

    /// A key went down (also used for popups opening and similar).
    func keyPress() {
        let strength = Prefs.vibration
        if strength > 0.01 {
            pressGenerator.impactOccurred(intensity: CGFloat(strength))
            pressGenerator.prepare()
        }
        if Prefs.clickSound {
            UIDevice.current.playInputClick()
        }
    }

    /// A lighter, rate-limited tick for continuous gestures (moving the cursor, deleting words).
    func tick() {
        let strength = Prefs.vibration
        guard strength > 0.01 else { return }
        let now = Date()
        guard now.timeIntervalSince(lastTick) > 0.035 else { return }
        lastTick = now
        tickGenerator.impactOccurred(intensity: CGFloat(max(0.25, strength * 0.7)))
        tickGenerator.prepare()
    }
}

// Lets the system play its key-click sound for this keyboard (only if the user has
// Settings > Sounds & Haptics > Keyboard Feedback > Sound switched on).
#if compiler(>=6.0)
extension UIInputView: @retroactive UIInputViewAudioFeedback {
    public var enableInputClicksWhenVisible: Bool { return true }
}
#else
extension UIInputView: UIInputViewAudioFeedback {
    public var enableInputClicksWhenVisible: Bool { return true }
}
#endif
