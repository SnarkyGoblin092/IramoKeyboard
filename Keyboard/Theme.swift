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

    // Key caps: translucent so the system keyboard backdrop shines through, like Liquid Glass.
    static let letterKey = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.24)
            : UIColor(white: 1.0, alpha: 0.80)
    }

    static let functionKey = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.11)
            : UIColor(white: 0.60, alpha: 0.36)
    }

    static let letterKeyPressed = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.45)
            : UIColor(white: 0.78, alpha: 0.90)
    }

    static let functionKeyPressed = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.30)
            : UIColor(white: 1.0, alpha: 0.85)
    }

    static let activeKey = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(white: 1.0, alpha: 0.92) : UIColor.white
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
