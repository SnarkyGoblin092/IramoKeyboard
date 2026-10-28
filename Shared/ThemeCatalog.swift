import Foundation
import CoreGraphics

// MARK: - Colour value

/// A plain RGBA colour (components 0...1). No UIKit/SwiftUI here, so the app and the keyboard can share it.
struct ThemeRGBA: Hashable {
    let r: Double
    let g: Double
    let b: Double
    let a: Double

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// 0xRRGGBB hex with optional alpha.
    init(hex: UInt32, alpha: Double = 1) {
        self.r = Double((hex >> 16) & 0xFF) / 255
        self.g = Double((hex >> 8) & 0xFF) / 255
        self.b = Double(hex & 0xFF) / 255
        self.a = alpha
    }
}

// MARK: - Theme definition

/// One keyboard theme. The keyboard (Keyboard/Theme.swift) and the app's theme picker both read this,
/// so previews always match the real thing.
struct ThemeDefinition: Hashable {

    enum Kind: String {
        /// Follows the system: native iOS keys on the system keyboard backdrop. Colour fields are ignored.
        case native
        /// See-through keys over the clear keyboard backdrop (the wallpaper/app shows through).
        case transparent
        /// A gradient backdrop behind translucent keys. Uses `gradient*` and the colour fields below.
        case gradient
        /// iOS 26 Liquid Glass keys/popups/strip (real `UIGlassEffect`); older iOS falls back to a blur.
        /// The backdrop is clear, so `gradient*` is ignored unless `gradientStops` is non-empty
        /// (then it is drawn faintly behind the glass so previews and fallbacks still have colour).
        case liquidGlass
    }

    /// Stored in `Settings.theme`. Never change an id once shipped.
    let id: String
    /// Name shown in the picker.
    let name: String
    let kind: Kind

    /// nil = follow the system light/dark setting. true/false forces the keyboard into dark/light.
    /// Gradient themes should force a style so the text colours below always read well.
    let isDark: Bool?

    // ---- Colours (used by .gradient, and as the base for .liquidGlass tints) ----

    /// Fill of a letter/number key.
    let key: ThemeRGBA
    /// Fill of a function key (shift, delete, 123, return, emoji...).
    let function: ThemeRGBA
    /// Fill of a key while it is pressed.
    let keyPressed: ThemeRGBA
    /// Fill of the pressed function key.
    let functionPressed: ThemeRGBA
    /// Hairline outline around keys (alpha 0 = none).
    let keyBorder: ThemeRGBA
    /// Colour of key labels, suggestions and icons.
    let text: ThemeRGBA
    /// Secondary labels (key hints, placeholders).
    let secondaryText: ThemeRGBA
    /// Accent: active shift, prominent return key, selected tab, swipe trail.
    let accent: ThemeRGBA
    /// Text/icon colour on top of the accent colour.
    let onAccent: ThemeRGBA
    /// Fill of popups (key balloon, long-press strip, skin-tone strip). Keep it nearly opaque.
    let popup: ThemeRGBA
    /// Fill of the suggestion strip and emoji search field / tab bar.
    let panel: ThemeRGBA

    // ---- Backdrop gradient (kind .gradient; faint for .liquidGlass) ----

    /// Colour stops from start to end. 2 or more entries for a gradient, empty for none.
    let gradientStops: [ThemeRGBA]
    /// Angle in degrees: 0 = left to right, 90 = top to bottom (clockwise), 135 = top-left to bottom-right.
    let gradientAngle: Double

    /// Start/end points in unit space (CAGradientLayer convention: (0,0) top-left, (1,1) bottom-right).
    var gradientStart: CGPoint {
        let rad = gradientAngle * Double.pi / 180
        return CGPoint(x: 0.5 - 0.5 * cos(rad), y: 0.5 - 0.5 * sin(rad))
    }

    var gradientEnd: CGPoint {
        let rad = gradientAngle * Double.pi / 180
        return CGPoint(x: 0.5 + 0.5 * cos(rad), y: 0.5 + 0.5 * sin(rad))
    }

    /// Evenly spaced stop locations 0...1.
    var gradientLocations: [Double] {
        let count = gradientStops.count
        guard count > 1 else { return [0] }
        return (0..<count).map { Double($0) / Double(count - 1) }
    }

    /// True when the keyboard should draw its own backdrop and a clear system background.
    var drawsBackdrop: Bool { return kind == .gradient && !gradientStops.isEmpty }
}

// MARK: - Catalog

enum ThemeCatalog {

    static let defaultID = "native"

    /// Picker order.
    static let all: [ThemeDefinition] = [
        native, transparent, liquidGlass,
        aurora, sunset, ocean, forest, midnight, rose, graphite, neon, lavender
    ]

    /// Unknown ids fall back to Native.
    static func theme(id: String) -> ThemeDefinition {
        for theme in all where theme.id == id { return theme }
        return native
    }

    // MARK: Helpers

    private static let clear = ThemeRGBA(0, 0, 0, 0)
    private static let white = ThemeRGBA(1, 1, 1, 1)

    /// Builds a gradient theme with legible translucent keys.
    /// `dark` themes use light text on dark glassy keys; light themes use dark text on white-ish keys.
    private static func gradient(id: String,
                                 name: String,
                                 dark: Bool,
                                 angle: Double,
                                 stops: [UInt32],
                                 accent: UInt32,
                                 onAccent: UInt32 = 0xFFFFFF) -> ThemeDefinition {
        let text = dark ? ThemeRGBA(1, 1, 1, 1) : ThemeRGBA(0.08, 0.08, 0.10, 1)
        let key = dark ? ThemeRGBA(1, 1, 1, 0.20) : ThemeRGBA(1, 1, 1, 0.62)
        let function = dark ? ThemeRGBA(0, 0, 0, 0.28) : ThemeRGBA(1, 1, 1, 0.34)
        return ThemeDefinition(
            id: id,
            name: name,
            kind: .gradient,
            isDark: dark,
            key: key,
            function: function,
            keyPressed: dark ? ThemeRGBA(1, 1, 1, 0.38) : ThemeRGBA(1, 1, 1, 0.90),
            functionPressed: dark ? ThemeRGBA(1, 1, 1, 0.30) : ThemeRGBA(1, 1, 1, 0.62),
            keyBorder: dark ? ThemeRGBA(1, 1, 1, 0.18) : ThemeRGBA(1, 1, 1, 0.55),
            text: text,
            secondaryText: dark ? ThemeRGBA(1, 1, 1, 0.65) : ThemeRGBA(0.08, 0.08, 0.10, 0.55),
            accent: ThemeRGBA(hex: accent),
            onAccent: ThemeRGBA(hex: onAccent),
            popup: dark ? ThemeRGBA(0.12, 0.12, 0.16, 0.96) : ThemeRGBA(1, 1, 1, 0.97),
            panel: dark ? ThemeRGBA(1, 1, 1, 0.14) : ThemeRGBA(1, 1, 1, 0.42),
            gradientStops: stops.map { ThemeRGBA(hex: $0) },
            gradientAngle: angle
        )
    }

    // MARK: Themes

    /// Follows the system exactly (native iOS look). Colour fields are placeholders for previews.
    static let native = ThemeDefinition(
        id: "native",
        name: "Native",
        kind: .native,
        isDark: nil,
        key: ThemeRGBA(1, 1, 1, 1),
        function: ThemeRGBA(0.67, 0.70, 0.74, 1),
        keyPressed: ThemeRGBA(0.67, 0.70, 0.74, 1),
        functionPressed: ThemeRGBA(1, 1, 1, 1),
        keyBorder: clear,
        text: ThemeRGBA(0, 0, 0, 1),
        secondaryText: ThemeRGBA(0, 0, 0, 0.5),
        accent: ThemeRGBA(hex: 0x0A84FF),
        onAccent: white,
        popup: ThemeRGBA(1, 1, 1, 1),
        panel: ThemeRGBA(1, 1, 1, 0.5),
        gradientStops: [ThemeRGBA(hex: 0xD2D5DB), ThemeRGBA(hex: 0xD2D5DB)],
        gradientAngle: 90
    )

    /// See-through keys over the clear backdrop.
    static let transparent = ThemeDefinition(
        id: "transparent",
        name: "Transparent",
        kind: .transparent,
        isDark: nil,
        key: ThemeRGBA(1, 1, 1, 0.22),
        function: ThemeRGBA(0.5, 0.5, 0.5, 0.18),
        keyPressed: ThemeRGBA(1, 1, 1, 0.45),
        functionPressed: ThemeRGBA(1, 1, 1, 0.35),
        keyBorder: ThemeRGBA(1, 1, 1, 0.35),
        text: ThemeRGBA(0, 0, 0, 1),
        secondaryText: ThemeRGBA(0, 0, 0, 0.5),
        accent: ThemeRGBA(hex: 0x0A84FF),
        onAccent: white,
        popup: ThemeRGBA(1, 1, 1, 0.96),
        panel: ThemeRGBA(1, 1, 1, 0.30),
        gradientStops: [ThemeRGBA(hex: 0x9AA4B5), ThemeRGBA(hex: 0xC9D1DE)],
        gradientAngle: 90
    )

    /// iOS 26 Liquid Glass. Glass keys float over a clear backdrop.
    static let liquidGlass = ThemeDefinition(
        id: "liquidglass",
        name: "Liquid Glass",
        kind: .liquidGlass,
        isDark: nil,
        key: ThemeRGBA(1, 1, 1, 0.12),
        function: ThemeRGBA(0.5, 0.55, 0.65, 0.16),
        keyPressed: ThemeRGBA(1, 1, 1, 0.34),
        functionPressed: ThemeRGBA(1, 1, 1, 0.28),
        keyBorder: ThemeRGBA(1, 1, 1, 0.22),
        text: ThemeRGBA(0, 0, 0, 1),
        secondaryText: ThemeRGBA(0, 0, 0, 0.5),
        accent: ThemeRGBA(hex: 0x0A84FF),
        onAccent: white,
        popup: ThemeRGBA(1, 1, 1, 0.9),
        panel: ThemeRGBA(1, 1, 1, 0.18),
        gradientStops: [ThemeRGBA(hex: 0x7FB2FF), ThemeRGBA(hex: 0xC9A8FF), ThemeRGBA(hex: 0xFFB8D0)],
        gradientAngle: 120
    )

    static let aurora = gradient(id: "aurora", name: "Aurora", dark: true, angle: 135,
                                 stops: [0x0F2027, 0x1B6E6A, 0x5B3FA0],
                                 accent: 0x4DF0C0, onAccent: 0x06231C)

    static let sunset = gradient(id: "sunset", name: "Sunset", dark: true, angle: 90,
                                 stops: [0x5B2A86, 0xD1456B, 0xFF9A4D],
                                 accent: 0xFFD166, onAccent: 0x3A1B00)

    static let ocean = gradient(id: "ocean", name: "Ocean", dark: true, angle: 100,
                                stops: [0x0B3D91, 0x1380C4, 0x3CC7D9],
                                accent: 0xFFFFFF, onAccent: 0x0B3D91)

    static let forest = gradient(id: "forest", name: "Forest", dark: true, angle: 120,
                                 stops: [0x0B2A1A, 0x1F6B3B, 0x7BAF52],
                                 accent: 0xC8F169, onAccent: 0x10300F)

    static let midnight = gradient(id: "midnight", name: "Midnight", dark: true, angle: 90,
                                   stops: [0x05060F, 0x131A3A, 0x2A2F6B],
                                   accent: 0x7C8CFF)

    static let rose = gradient(id: "rose", name: "Rose", dark: false, angle: 135,
                               stops: [0xFFD6E0, 0xFFB3C7, 0xF78FB3],
                               accent: 0xE0457B)

    static let graphite = gradient(id: "graphite", name: "Graphite", dark: true, angle: 90,
                                   stops: [0x2B2D31, 0x1B1C1F],
                                   accent: 0xFF9F0A, onAccent: 0x2A1700)

    static let neon = gradient(id: "neon", name: "Neon", dark: true, angle: 45,
                               stops: [0x12002B, 0x4A00A0, 0xE100A8],
                               accent: 0x00F5D4, onAccent: 0x00231F)

    static let lavender = gradient(id: "lavender", name: "Lavender", dark: false, angle: 120,
                                   stops: [0xE9E4FF, 0xCFC3FF, 0xA9B8FF],
                                   accent: 0x6C5CE7)
}
