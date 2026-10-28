import UIKit

extension AccentChoice {
    var uiColor: UIColor {
        let value = rgb
        return UIColor(red: CGFloat(value.red), green: CGFloat(value.green), blue: CGFloat(value.blue), alpha: 1)
    }
}

/// Colours for the two themes: "native" (the iOS keyboard look) and "transparent" (see-through keys).
/// Every colour follows light / dark mode automatically. The theme is read whenever a colour is
/// resolved, and the keyboard rebuilds itself when the theme setting changes.
enum Theme {
    static var accent: UIColor { return Settings.shared.accent.uiColor }

    static var isTransparent: Bool { return Settings.shared.isTransparentTheme }

    /// The transparent theme wants the system keyboard backdrop removed so the keys float on the screen.
    static var wantsClearBackdrop: Bool { return isTransparent }

    private static func dynamic(native: @escaping (Bool) -> UIColor,
                                transparent: @escaping (Bool) -> UIColor) -> UIColor {
        return UIColor { trait in
            let dark = trait.userInterfaceStyle == .dark
            return isTransparent ? transparent(dark) : native(dark)
        }
    }

    private static let nativeFunction = UIColor(red: 0.675, green: 0.702, blue: 0.745, alpha: 1)

    static let letterKey = dynamic(
        native: { $0 ? UIColor(white: 0.42, alpha: 1) : UIColor.white },
        transparent: { $0 ? UIColor(white: 1.0, alpha: 0.16) : UIColor(white: 1.0, alpha: 0.34) })

    static let functionKey = dynamic(
        native: { $0 ? UIColor(white: 0.27, alpha: 1) : nativeFunction },
        transparent: { $0 ? UIColor(white: 0.0, alpha: 0.28) : UIColor(white: 0.0, alpha: 0.12) })

    // Pressed letter keys turn into the function-key colour and vice versa, like iOS.
    static let letterKeyPressed = dynamic(
        native: { $0 ? UIColor(white: 0.27, alpha: 1) : nativeFunction },
        transparent: { $0 ? UIColor(white: 1.0, alpha: 0.32) : UIColor(white: 1.0, alpha: 0.62) })

    static let functionKeyPressed = dynamic(
        native: { $0 ? UIColor(white: 0.42, alpha: 1) : UIColor.white },
        transparent: { $0 ? UIColor(white: 1.0, alpha: 0.24) : UIColor(white: 1.0, alpha: 0.50) })

    /// Shift when it is on.
    static let activeKey = dynamic(
        native: { _ in UIColor.white },
        transparent: { $0 ? UIColor(white: 1.0, alpha: 0.78) : UIColor(white: 1.0, alpha: 0.88) })

    static let keyShadow = dynamic(
        native: { $0 ? UIColor(white: 0.0, alpha: 0.55) : UIColor(red: 0.53, green: 0.55, blue: 0.58, alpha: 1) },
        transparent: { _ in UIColor.clear })

    /// Thin outline of a key (transparent theme only; the native theme has none).
    static let keyBorder = dynamic(
        native: { _ in UIColor.clear },
        transparent: { $0 ? UIColor(white: 1.0, alpha: 0.28) : UIColor(white: 1.0, alpha: 0.70) })

    /// Pop-ups (key balloon, accent strip) stay nearly opaque in both themes so the letter is readable.
    static let popupFill = dynamic(
        native: { $0 ? UIColor(white: 0.42, alpha: 1) : UIColor.white },
        transparent: { $0 ? UIColor(white: 0.30, alpha: 0.97) : UIColor(white: 1.0, alpha: 0.97) })

    /// Backdrop for full-keyboard panels (emoji picker, quick settings).
    static let panelBackground = dynamic(
        native: { $0 ? UIColor(white: 0.17, alpha: 1) : UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1) },
        transparent: { $0 ? UIColor(white: 0.10, alpha: 0.72) : UIColor(white: 0.92, alpha: 0.72) })

    /// Rounded text-field look for the emoji search field.
    static let searchField = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.16)
            : UIColor(white: 0.0, alpha: 0.08)
    }

    static let separator = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.20)
            : UIColor(white: 0.0, alpha: 0.12)
    }
}
