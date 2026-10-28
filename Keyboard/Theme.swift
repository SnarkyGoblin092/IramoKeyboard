import UIKit

/// Colours that follow light / dark mode automatically.
enum Theme {
    static let panelBackground = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.13, alpha: 1)
            : UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1)
    }

    static let letterKey = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(white: 0.42, alpha: 1) : UIColor.white
    }

    static let functionKey = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(white: 0.26, alpha: 1) : UIColor(white: 0.68, alpha: 1)
    }

    static let letterKeyPressed = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(white: 0.58, alpha: 1) : UIColor(white: 0.80, alpha: 1)
    }

    static let functionKeyPressed = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(white: 0.42, alpha: 1) : UIColor.white
    }

    static let activeKey = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(white: 0.88, alpha: 1) : UIColor.white
    }

    static let accent = UIColor.systemBlue
}
