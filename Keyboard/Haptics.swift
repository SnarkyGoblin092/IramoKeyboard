import AudioToolbox
import UIKit

/// Key-press vibration with adjustable strength, plus the optional system key-click sound.
///
/// iOS only lets keyboard extensions use the haptic engine when the user has switched on
/// "Allow Full Access" for the keyboard (Settings > General > Keyboard > Keyboards > Iramo).
final class Haptics {
    static let shared = Haptics()

    /// Key presses use the style the haptic "feel" picks (soft ... rigid); see `style(forSharpness:)`.
    private var pressStyle = UIImpactFeedbackGenerator.FeedbackStyle.rigid
    private var pressGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let tickGenerator = UIImpactFeedbackGenerator(style: .soft)
    private var lastTick = Date.distantPast
    /// Set by the keyboard when it appears. System sounds only play with Full Access.
    var hasFullAccess = false

    /// The system keyboard's key-tap sound.
    private static let keyTapSound: SystemSoundID = 1104

    private init() {}

    /// The haptic feel's sharpness (0 = soft ... 1 = rigid) as one of the system's impact styles. Mirrored by
    /// the app's Haptics screen (Feedback.test).
    static func style(forSharpness sharpness: Double) -> UIImpactFeedbackGenerator.FeedbackStyle {
        switch sharpness {
        case ..<0.2: return .soft
        case ..<0.4: return .light
        case ..<0.6: return .medium
        case ..<0.8: return .heavy
        default: return .rigid
        }
    }

    private func updateStyle() {
        let style = Haptics.style(forSharpness: Prefs.hapticSharpness)
        guard style != pressStyle else { return }
        pressStyle = style
        pressGenerator = UIImpactFeedbackGenerator(style: style)
        pressGenerator.prepare()
    }

    func prepare() {
        updateStyle()
        pressGenerator.prepare()
        tickGenerator.prepare()
    }

    /// A key went down (also used for popups opening and similar).
    func keyPress() {
        let strength = Prefs.vibration
        if strength > 0.01 {
            updateStyle()
            pressGenerator.impactOccurred(intensity: CGFloat(strength))
            pressGenerator.prepare()
        }
        if Prefs.clickSound {
            // `playInputClick` is usually silent in keyboard extensions, so play the system key-tap
            // sound (it follows the silent switch). Without Full Access only the input click can work.
            if hasFullAccess {
                AudioServicesPlaySystemSound(Haptics.keyTapSound)
            } else {
                UIDevice.current.playInputClick()
            }
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
