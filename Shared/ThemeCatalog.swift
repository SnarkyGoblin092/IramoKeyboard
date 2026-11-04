import Foundation
import CoreGraphics

// MARK: - Colour value

/// A plain RGBA colour (components 0...1). No UIKit/SwiftUI here, so the app and the keyboard can share it.
struct ThemeRGBA: Hashable, Codable {
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
/// so previews always match the real thing. All three follow the system's light and dark mode.
struct ThemeDefinition: Hashable {

    enum Kind: String {
        /// Native iOS keys on the system keyboard backdrop.
        case native
        /// See-through keys over the clear keyboard backdrop (the wallpaper/app shows through).
        case transparent
        /// iOS 26 Liquid Glass keys/popups/strip (real `UIGlassEffect`); older iOS falls back to a blur.
        case liquidGlass
        /// Solid keys on a backdrop of the theme's own colours (`colors`), one set for light and one for dark.
        case colored
    }

    /// Stored in `Settings.theme`. Never change an id once shipped.
    let id: String
    /// Name shown in the picker.
    let name: String
    let kind: Kind
    /// What makes it different, in a few words (the editor's subtitle).
    let summary: String
    /// True when the user changed this theme in its editor.
    var isEdited = false
    /// The theme's own style from its editor (nil: not edited, so the old global key settings apply).
    var systemStyle: SystemStyle? = nil
    /// A colour theme's own colours (nil for the others).
    var colors: ThemeColors? = nil

    /// Solid keys like the iOS keyboard's: no outline by default, and the 1pt shadow line under them.
    var hasSolidKeys: Bool { return kind == .native || kind == .colored }
}

/// A colour theme's colours in one appearance.
struct ThemeTones: Hashable {
    /// Behind the keys (and the suggestion bar).
    let panel: ThemeRGBA
    let key: ThemeRGBA
    let function: ThemeRGBA
    /// Labels and the suggestion bar's words.
    let text: ThemeRGBA
    /// Return, shift when on, the suggestion pill and the bar's icons.
    let accent: ThemeRGBA

    init(_ panel: UInt32, _ key: UInt32, _ function: UInt32, _ text: UInt32, _ accent: UInt32) {
        self.panel = ThemeRGBA(hex: panel)
        self.key = ThemeRGBA(hex: key)
        self.function = ThemeRGBA(hex: function)
        self.text = ThemeRGBA(hex: text)
        self.accent = ThemeRGBA(hex: accent)
    }

    /// Near-black on light accents (yellow, mint...), white on dark ones.
    var accentIsLight: Bool {
        return 0.299 * accent.r + 0.587 * accent.g + 0.114 * accent.b > 0.62
    }
}

/// A colour theme's colours: one set for light apps, one for dark apps.
struct ThemeColors: Hashable {
    let light: ThemeTones
    let dark: ThemeTones

    func tones(dark isDark: Bool) -> ThemeTones { return isDark ? dark : light }
}

// MARK: - Catalog

enum ThemeCatalog {

    static let defaultID = "native"

    /// The themes, in picker order.
    static let all: [ThemeDefinition] = [native, transparent, liquidGlass] + colorThemes

    /// The theme as it comes, without the user's edits. Unknown ids (including the removed designed and key-colour
    /// themes) fall back to Native.
    static func base(id: String) -> ThemeDefinition {
        for theme in all where theme.id == id { return theme }
        return native
    }

    /// Themes with their stored edits (decoded once for all of them).
    static func themes(_ bases: [ThemeDefinition]) -> [ThemeDefinition] {
        let edits = SystemEdits.decode(SharedStore.defaults.string(forKey: SettingKey.systemEdits) ?? "")
        return bases.map { base in
            var theme = base
            if let style = edits[theme.id] {
                theme.systemStyle = style
                theme.isEdited = true
            }
            return theme
        }
    }

    /// The theme with the stored edits.
    static func theme(id: String) -> ThemeDefinition {
        return themes([base(id: id)])[0]
    }

    /// Native iOS look.
    static let native = ThemeDefinition(id: "native", name: "Native", kind: .native,
                                        summary: "The iOS keyboard, in light and dark mode")

    /// See-through keys over the clear backdrop.
    static let transparent = ThemeDefinition(id: "transparent", name: "Transparent", kind: .transparent,
                                             summary: "See-through keys over a frosted panel")

    /// iOS 26 Liquid Glass. Glass keys float over a clear backdrop.
    static let liquidGlass = ThemeDefinition(id: "liquidglass", name: "Liquid Glass", kind: .liquidGlass,
                                             summary: "Real Liquid Glass keys over the app")

    private static func colored(_ id: String, _ name: String, _ summary: String,
                                light: ThemeTones, dark: ThemeTones) -> ThemeDefinition {
        return ThemeDefinition(id: id, name: name, kind: .colored, summary: summary,
                               colors: ThemeColors(light: light, dark: dark))
    }

    // Tones: panel, key, function key, text, accent. Each theme has a light set for light apps and a dark set
    // for dark apps.
    static let colorThemes: [ThemeDefinition] = [
        colored("ocean", "Ocean", "Deep sea blues",
                light: ThemeTones(0xD3E4F1, 0xFFFFFF, 0xA7C4DC, 0x0B2A40, 0x1677C9),
                dark: ThemeTones(0x0A1B2A, 0x1F3B55, 0x14293D, 0xE3F1FC, 0x4AA8F0)),
        colored("forest", "Forest", "Moss and pine greens",
                light: ThemeTones(0xD5E3D3, 0xFFFFFF, 0xACC6A9, 0x1C3320, 0x2E7D32),
                dark: ThemeTones(0x0E1C11, 0x25402A, 0x182C1C, 0xE2F1E2, 0x66BB6A)),
        colored("sunset", "Sunset", "Warm orange glow",
                light: ThemeTones(0xF5DACA, 0xFFF8F3, 0xE6B498, 0x4A2316, 0xE8603C),
                dark: ThemeTones(0x23110F, 0x4A2A22, 0x331B16, 0xFBE6DC, 0xFF8A5C)),
        colored("lavender", "Lavender", "Soft violet",
                light: ThemeTones(0xE4DBF1, 0xFFFFFF, 0xC7B5E2, 0x2E2142, 0x7E57C2),
                dark: ThemeTones(0x191325, 0x382C4D, 0x271F37, 0xEEE6FA, 0xB39DDB)),
        colored("sakura", "Sakura", "Cherry blossom pinks",
                light: ThemeTones(0xF8E1EA, 0xFFFFFF, 0xEDBDD0, 0x4A2434, 0xD94F84),
                dark: ThemeTones(0x22151B, 0x46303B, 0x31222A, 0xFBEAF0, 0xF48FB1)),
        colored("mint", "Mint", "Fresh and cool",
                light: ThemeTones(0xD7EFE6, 0xFFFFFF, 0xA6DAC6, 0x103B2E, 0x0F9C78),
                dark: ThemeTones(0x0B201A, 0x1F4A3C, 0x15342A, 0xDDF6EE, 0x4FD1A5)),
        colored("sand", "Sand", "Warm beige and gold",
                light: ThemeTones(0xECE1CE, 0xFFFCF5, 0xD5C09C, 0x3D3122, 0xA87A22),
                dark: ThemeTones(0x1D1811, 0x3F3527, 0x2C251B, 0xF4EBDB, 0xD9A84E)),
        colored("slate", "Slate", "Quiet blue-grey",
                light: ThemeTones(0xD3D8DF, 0xF7F9FB, 0xACB5C1, 0x1F2933, 0x3E5C76),
                dark: ThemeTones(0x14181D, 0x2E353D, 0x21262C, 0xE4E9EE, 0x8AA4BC)),
        colored("cherry", "Cherry", "Bold reds",
                light: ThemeTones(0xF2D4D4, 0xFFFFFF, 0xDEA2A2, 0x3F1010, 0xC62828),
                dark: ThemeTones(0x1E0A0A, 0x451C1C, 0x301313, 0xFADCDC, 0xEF5350)),
        colored("citrus", "Citrus", "Lemon and lime",
                light: ThemeTones(0xF2EBC3, 0xFFFFF5, 0xDFD086, 0x3A3410, 0xE0A800),
                dark: ThemeTones(0x1D1A09, 0x3F3A17, 0x2C2810, 0xF7F1CF, 0xFFD54F)),
        colored("midnight", "Midnight", "Indigo night sky",
                light: ThemeTones(0xD8DBEF, 0xFFFFFF, 0xB2B7DE, 0x1A1F4A, 0x3949AB),
                dark: ThemeTones(0x090C1E, 0x1E2447, 0x141933, 0xE1E5FF, 0x7986CB)),
        colored("lagoon", "Lagoon", "Tropical teal",
                light: ThemeTones(0xD2ECEF, 0xFFFFFF, 0xA3D6DC, 0x0F3438, 0x00909E),
                dark: ThemeTones(0x091D20, 0x1B4247, 0x132F33, 0xDAF5F7, 0x26C6DA)),
        colored("mocha", "Mocha", "Coffee and cream",
                light: ThemeTones(0xE6DAD0, 0xFBF7F3, 0xCBB5A4, 0x3B2A20, 0x8D5B3E),
                dark: ThemeTones(0x1B1410, 0x3B2E26, 0x2A201A, 0xF1E6DE, 0xC49A7A)),
        colored("graphite", "Graphite", "Pure black and white",
                light: ThemeTones(0xE0E0E0, 0xFFFFFF, 0xBBBBBB, 0x111111, 0x2B2B2B),
                dark: ThemeTones(0x0D0D0D, 0x2A2A2A, 0x1C1C1C, 0xF2F2F2, 0xE6E6E6)),
        colored("neon", "Neon", "Electric magenta",
                light: ThemeTones(0xECE6F7, 0xFFFFFF, 0xD3C5ED, 0x1B1033, 0xD81B8C),
                dark: ThemeTones(0x09060F, 0x1E1530, 0x140E22, 0xF3EDFF, 0xFF3EC8)),
        colored("olive", "Olive", "Earthy green-gold",
                light: ThemeTones(0xDADDC6, 0xFDFDF6, 0xBCC199, 0x2A2E14, 0x6B7A1E),
                dark: ThemeTones(0x16180F, 0x33382A, 0x24281C, 0xEEF0E0, 0xAABB55)),
        colored("plum", "Plum", "Rich purple-red",
                light: ThemeTones(0xE8D6E5, 0xFFFFFF, 0xCFACCA, 0x3A1435, 0x8E2C82),
                dark: ThemeTones(0x1B0E1A, 0x3E2639, 0x2B1A28, 0xF6E5F3, 0xCE6FC2)),
        colored("terminal", "Terminal", "Retro green screen",
                light: ThemeTones(0xE0EBE0, 0xFFFFFF, 0xBCD1BC, 0x0F2A12, 0x1B8F3A),
                dark: ThemeTones(0x040804, 0x0F1F11, 0x0A150B, 0x8CFF9C, 0x33D35A)),
        colored("frost", "Frost", "Icy pale blues",
                light: ThemeTones(0xE3E8EF, 0xFFFFFF, 0xC5CEDC, 0x26303D, 0x4C7BB0),
                dark: ThemeTones(0x1C222B, 0x343E4C, 0x28303B, 0xEAF0F6, 0x8CC4D8)),
        colored("copper", "Copper", "Burnished metal",
                light: ThemeTones(0xE8D7CB, 0xFFF9F5, 0xD3AF98, 0x3C2416, 0xB0601A),
                dark: ThemeTones(0x1A110C, 0x3D2A1F, 0x2B1D15, 0xF4E4D8, 0xE08E4F)),
    ]
}
