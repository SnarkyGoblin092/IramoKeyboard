import UIKit

extension AccentChoice {
    var uiColor: UIColor {
        let value = rgb
        return UIColor(red: CGFloat(value.red), green: CGFloat(value.green), blue: CGFloat(value.blue), alpha: 1)
    }
}

/// Colours for the glass look. Every colour follows light / dark mode automatically.
enum Theme {
    static var accent: UIColor { return Settings.shared.accent.uiColor }

    // Native iOS keyboard colours (opaque key caps on the system keyboard backdrop).
    static let letterKey = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.42, alpha: 1)
            : UIColor.white
    }

    static let functionKey = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.27, alpha: 1)
            : UIColor(red: 0.675, green: 0.702, blue: 0.745, alpha: 1)
    }

    // Pressed letter keys turn into the function-key colour and vice versa, like iOS.
    static let letterKeyPressed = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.27, alpha: 1)
            : UIColor(red: 0.675, green: 0.702, blue: 0.745, alpha: 1)
    }

    static let functionKeyPressed = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.42, alpha: 1)
            : UIColor.white
    }

    static let activeKey = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor.white : UIColor.white
    }

    static let keyShadow = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.0, alpha: 0.55)
            : UIColor(red: 0.53, green: 0.55, blue: 0.58, alpha: 1)
    }

    /// Opaque backdrop for full-keyboard panels (emoji picker, quick settings).
    static let panelBackground = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.17, alpha: 1)
            : UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1)
    }

    /// Rounded text-field look for the emoji search field.
    static let searchField = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.16)
            : UIColor(white: 0.0, alpha: 0.08)
    }

    static let keyBorder = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.22)
            : UIColor(white: 1.0, alpha: 0.95)
    }

    static let separator = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.20)
            : UIColor(white: 0.0, alpha: 0.12)
    }

    // Overlays used when the keys are real glass.
    static let glassFunctionOverlay = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.06)
            : UIColor(white: 0.0, alpha: 0.10)
    }

    static let glassPressedOverlay = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.30)
            : UIColor(white: 1.0, alpha: 0.65)
    }
}
