import UIKit

/// Key-press vibration with adjustable strength.
///
/// iOS only lets keyboard extensions use the haptic engine when the user has switched on
/// "Allow Full Access" for the keyboard (Settings > General > Keyboard > Keyboards > HunKeys).
final class Haptics {
    static let shared = Haptics()

    private let generator = UIImpactFeedbackGenerator(style: .rigid)

    private init() {}

    func prepare() {
        generator.prepare()
    }

    func keyPress() {
        let strength = Settings.shared.vibrationStrength
        guard strength > 0.01 else { return }
        generator.impactOccurred(intensity: CGFloat(strength))
        generator.prepare()
    }
}
