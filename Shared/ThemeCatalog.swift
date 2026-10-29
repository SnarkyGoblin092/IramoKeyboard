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

extension ThemeRGBA {
    /// Parses "#RRGGBB" / "RRGGBB" (optionally "#RRGGBBAA"). Returns nil when invalid.
    init?(hexString: String) {
        var text = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6 || text.count == 8, let value = UInt64(text, radix: 16) else { return nil }
        if text.count == 6 {
            self.init(hex: UInt32(value))
        } else {
            self.init(hex: UInt32(value >> 8), alpha: Double(value & 0xFF) / 255)
        }
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
        /// Coloured keys on the normal system keyboard background. Only the keys change colour.
        case colored
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
    var drawsBackdrop: Bool { return false }
}

// MARK: - Catalog

enum ThemeCatalog {

    static let defaultID = "native"

    /// Picker order.
    static let all: [ThemeDefinition] = [
        native, transparent, liquidGlass,
        ocean, forest, sunset, aurora, rose, lavender, graphite, midnight, neon
    ]

    /// Unknown ids (including the removed "custom" theme) fall back to Native.
    static func theme(id: String) -> ThemeDefinition {
        for theme in all where theme.id == id { return theme }
        return native
    }

    // MARK: Helpers

    private static let clear = ThemeRGBA(0, 0, 0, 0)
    private static let white = ThemeRGBA(1, 1, 1, 1)

    /// Mixes a colour toward white (amount > 0) or black (amount < 0).
    private static func shade(_ hex: UInt32, _ amount: Double) -> ThemeRGBA {
        let base = ThemeRGBA(hex: hex)
        let target: Double = amount >= 0 ? 1 : 0
        let t = abs(amount)
        return ThemeRGBA(base.r + (target - base.r) * t, base.g + (target - base.g) * t, base.b + (target - base.b) * t, 1)
    }

    /// Coloured keys on the normal system background: letter keys use `key`, function keys a deeper shade.
    /// `lightText` picks white labels (dark keys) or near-black labels (light keys).
    private static func colored(id: String,
                                name: String,
                                key: UInt32,
                                lightText: Bool,
                                accent: UInt32,
                                onAccent: UInt32 = 0xFFFFFF) -> ThemeDefinition {
        let text = lightText ? ThemeRGBA(1, 1, 1, 1) : ThemeRGBA(0.08, 0.08, 0.10, 1)
        return ThemeDefinition(
            id: id,
            name: name,
            kind: .colored,
            isDark: nil,
            key: shade(key, 0),
            function: shade(key, -0.30),
            keyPressed: shade(key, lightText ? 0.25 : -0.12),
            functionPressed: shade(key, lightText ? 0.10 : -0.40),
            keyBorder: clear,
            text: text,
            secondaryText: ThemeRGBA(text.r, text.g, text.b, 0.65),
            accent: ThemeRGBA(hex: accent),
            onAccent: ThemeRGBA(hex: onAccent),
            popup: shade(key, 0),
            panel: ThemeRGBA(0, 0, 0, 0.08),
            gradientStops: [],
            gradientAngle: 90
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

    static let ocean = colored(id: "ocean", name: "Ocean", key: 0x2F7FD6, lightText: true, accent: 0xFFFFFF, onAccent: 0x0B3D91)
    static let forest = colored(id: "forest", name: "Forest", key: 0x3A8F5A, lightText: true, accent: 0xC8F169, onAccent: 0x10300F)
    static let sunset = colored(id: "sunset", name: "Sunset", key: 0xE2703A, lightText: true, accent: 0xFFD166, onAccent: 0x3A1B00)
    static let aurora = colored(id: "aurora", name: "Aurora", key: 0x1F9A94, lightText: true, accent: 0x4DF0C0, onAccent: 0x06231C)
    static let rose = colored(id: "rose", name: "Rose", key: 0xF4A3BF, lightText: false, accent: 0xE0457B)
    static let lavender = colored(id: "lavender", name: "Lavender", key: 0xC4B8FF, lightText: false, accent: 0x6C5CE7)
    static let graphite = colored(id: "graphite", name: "Graphite", key: 0x55585F, lightText: true, accent: 0xFF9F0A, onAccent: 0x2A1700)
    static let midnight = colored(id: "midnight", name: "Midnight", key: 0x303A85, lightText: true, accent: 0x7C8CFF)
    static let neon = colored(id: "neon", name: "Neon", key: 0x8A2BE2, lightText: true, accent: 0x00F5D4, onAccent: 0x00231F)
}
