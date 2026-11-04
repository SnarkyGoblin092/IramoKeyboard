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

    /// This colour moved `amount` (0...1) of the way toward `other`.
    func mixed(with other: ThemeRGBA, _ amount: Double) -> ThemeRGBA {
        return ThemeRGBA(r + (other.r - r) * amount, g + (other.g - g) * amount, b + (other.b - b) * amount, a)
    }

    var luminance: Double { return 0.299 * r + 0.587 * g + 0.114 * b }

    static let black = ThemeRGBA(0, 0, 0)
    static let white = ThemeRGBA(1, 1, 1)
}

// MARK: - Theme definition

/// One keyboard theme. The keyboard (Keyboard/Theme.swift) and the app's theme picker both read this,
/// so previews always match the real thing. All of them follow the system's light and dark mode.
struct ThemeDefinition: Hashable {

    enum Kind: String {
        /// Native iOS keys on the system keyboard backdrop.
        case native
        /// See-through keys over the clear keyboard backdrop (the wallpaper/app shows through).
        case transparent
        /// iOS 26 Liquid Glass keys/popups/strip (real `UIGlassEffect`); older iOS falls back to a blur.
        case liquidGlass
        /// 3D keycaps in the theme's own colours (`colors`) on the system keyboard backdrop.
        case keycap
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
    /// The theme's own style from its editor (nil: not edited, so the old global key settings apply). A keycap
    /// theme comes with one of its own.
    var systemStyle: SystemStyle? = nil
    /// A keycap theme's colours (nil for the others).
    var colors: ThemeColors? = nil
    /// The picker section a keycap theme is listed under (its family of colourways).
    var family: String? = nil
    /// A keycap theme's own font (a KeyFont id), used while the Keys screen's font is System.
    var font: String? = nil

    /// Solid keys like the iOS keyboard's: no outline by default.
    var hasSolidKeys: Bool { return kind == .native || kind == .keycap }

    /// The font the keys use: the Keys screen's, or this theme's own while that is System.
    func fontID(chosen: String) -> String {
        return chosen == KeyFont.system.rawValue ? (font ?? chosen) : chosen
    }
}

/// The keys a keycap theme can colour on their own.
enum KeyRole: Hashable {
    case letter, function, shift, delete, numbers, space, ret
}

/// The 3D keycap's shape: how deep its skirt is and how far its face sits in from the sides.
enum Keycap {
    /// The skirt under the face, for a key of this height.
    static func depth(height: CGFloat) -> CGFloat { return min(4.5, max(2, height * 0.1)) }
    /// The skirt showing at each side of the face.
    static let sideInset: CGFloat = 1
    /// How far the skirt is shaded under the face's colour (light and dark mode).
    static func skirtShade(dark: Bool) -> Double { return dark ? 0.45 : 0.24 }
}

/// A keycap theme's colours in one appearance (light or dark).
struct ThemeTones: Hashable {
    let key: ThemeRGBA
    let text: ThemeRGBA
    let function: ThemeRGBA
    let shift: ThemeRGBA
    let delete: ThemeRGBA
    let numbers: ThemeRGBA
    let space: ThemeRGBA
    let ret: ThemeRGBA

    /// `key`/`text`: the letter keys. The modifiers left out of `mods` take the plain function key colour (the
    /// letter colour, a shade darker in light mode and lighter in dark mode).
    init(key: UInt32, text: UInt32, dark: Bool, mods: KeyMods) {
        let key = ThemeRGBA(hex: key)
        let function = dark ? key.mixed(with: .white, 0.08) : key.mixed(with: .black, 0.1)
        self.key = key
        self.text = ThemeRGBA(hex: text)
        self.function = function
        self.shift = mods.shift.map { ThemeRGBA(hex: $0) } ?? function
        self.delete = mods.delete.map { ThemeRGBA(hex: $0) } ?? function
        self.numbers = mods.numbers.map { ThemeRGBA(hex: $0) } ?? function
        self.space = mods.space.map { ThemeRGBA(hex: $0) } ?? key
        self.ret = ThemeRGBA(hex: mods.ret)
    }

    func fill(_ role: KeyRole) -> ThemeRGBA {
        switch role {
        case .letter: return key
        case .function: return function
        case .shift: return shift
        case .delete: return delete
        case .numbers: return numbers
        case .space: return space
        case .ret: return ret
        }
    }

    /// The label on a key: the theme's text on the plain keys, else dark or white by how light the key is.
    func label(_ role: KeyRole) -> ThemeRGBA {
        let color = fill(role)
        if color == key || color == function { return text }
        return color.luminance > 0.6 ? ThemeRGBA(hex: 0x1E1E1E) : .white
    }
}

/// The modifier colours of a colourway (nil: the plain function key colour; space: the letter colour).
struct KeyMods {
    var shift: UInt32? = nil
    var delete: UInt32? = nil
    var numbers: UInt32? = nil
    var space: UInt32? = nil
    var ret: UInt32
}

/// A keycap theme's colours: one set for light apps, one for dark apps.
struct ThemeColors: Hashable {
    let light: ThemeTones
    let dark: ThemeTones

    func tones(dark isDark: Bool) -> ThemeTones { return isDark ? dark : light }
}

// MARK: - Catalog

enum ThemeCatalog {

    static let defaultID = "native"

    /// The themes, in picker order.
    static let all: [ThemeDefinition] = [native, transparent, liquidGlass] + keycapThemes

    /// The keycap families, in picker order.
    static let families = ["Arcade", "Studio", "Solo", "Café", "Tide"]

    /// The theme as it comes, without the user's edits. Unknown ids (including removed themes) fall back to Native.
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

    // MARK: Keycap themes

    /// One colourway of a family. `light`/`dark`: the letter keys and their labels in each mode (0xKEY, 0xTEXT).
    private static func colourway(_ family: String, _ variant: String, font: String?, roundness: Double,
                                  light: (UInt32, UInt32), dark: (UInt32, UInt32), mods: KeyMods) -> ThemeDefinition {
        var style = SystemStyle()
        style.roundness = roundness
        style.surface = "sheen"   // the face catches the light at the top
        style.border = "none"
        let id = "\(family)-\(variant)".lowercased().folding(options: .diacriticInsensitive, locale: nil)
        return ThemeDefinition(id: id, name: "\(family) \(variant)", kind: .keycap,
                               summary: "\(variant) 3D keycaps", systemStyle: style,
                               colors: ThemeColors(light: ThemeTones(key: light.0, text: light.1, dark: false, mods: mods),
                                                   dark: ThemeTones(key: dark.0, text: dark.1, dark: true, mods: mods)),
                               family: family, font: font)
    }

    /// Cream caps with candy-coloured modifiers.
    private static func arcade(_ variant: String, light: (UInt32, UInt32), dark: (UInt32, UInt32),
                               _ mods: KeyMods) -> ThemeDefinition {
        return colourway("Arcade", variant, font: "mono", roundness: 0.28, light: light, dark: dark, mods: mods)
    }

    /// Neutral caps with one or two bright accents.
    private static func studio(_ variant: String, light: (UInt32, UInt32), dark: (UInt32, UInt32),
                               _ mods: KeyMods) -> ThemeDefinition {
        return colourway("Studio", variant, font: nil, roundness: 0.34, light: light, dark: dark, mods: mods)
    }

    /// Plain caps; shift, 123 and return in a single colour.
    private static func solo(_ variant: String, _ accent: UInt32) -> ThemeDefinition {
        return colourway("Solo", variant, font: "rounded", roundness: 0.3,
                         light: (0xFAFAFA, 0x2C2C2E), dark: (0x3A3A3D, 0xF2F2F4),
                         mods: KeyMods(shift: accent, numbers: accent, ret: accent))
    }

    /// Warm cream caps with softly rounded edges.
    private static func cafe(_ variant: String, light: (UInt32, UInt32), dark: (UInt32, UInt32),
                             _ mods: KeyMods) -> ThemeDefinition {
        return colourway("Café", variant, font: "rounded", roundness: 0.42, light: light, dark: dark, mods: mods)
    }

    /// Caps tinted through in one colour.
    private static func tide(_ variant: String, light: (UInt32, UInt32), dark: (UInt32, UInt32),
                             _ mods: KeyMods) -> ThemeDefinition {
        return colourway("Tide", variant, font: nil, roundness: 0.36, light: light, dark: dark, mods: mods)
    }

    static let keycapThemes: [ThemeDefinition] = [
        arcade("Classic", light: (0xF4EFDD, 0x2B2A27), dark: (0x3B3936, 0xEEEAE0),
               KeyMods(shift: 0xD6454A, delete: 0xDE7A36, numbers: 0xE2C445, ret: 0x4D93D9)),
        arcade("Pastel", light: (0xFBF6F0, 0x3A3340), dark: (0x3E3946, 0xF3EEF6),
               KeyMods(shift: 0xEF8AA6, delete: 0xF3B26B, numbers: 0x9FD8B0, ret: 0x94B3EE)),
        arcade("Dusk", light: (0xF2ECE6, 0x2E2733), dark: (0x2F2A36, 0xEDE6F2),
               KeyMods(shift: 0xA84BC8, delete: 0xE2577C, numbers: 0xEFA23E, ret: 0x3CB1AD)),
        arcade("Citrus", light: (0xF6F3E4, 0x2C2B22), dark: (0x34342C, 0xEEEDE2),
               KeyMods(shift: 0x7DBB42, delete: 0xF2A93B, numbers: 0xF4D35E, ret: 0xE4573D)),

        studio("Aurora", light: (0xE9EAEE, 0x2B2D33), dark: (0x35373C, 0xE6E7EB),
               KeyMods(shift: 0x5EC3A6, delete: 0xE6C342, numbers: 0x5EC3A6, ret: 0xE2694E)),
        studio("Volt", light: (0xEEF1E6, 0x2C3122), dark: (0x2E3128, 0xD9EE9A),
               KeyMods(shift: 0xB6DB4C, numbers: 0xB6DB4C, ret: 0xB6DB4C)),
        studio("Violet", light: (0xECEAF3, 0x2A2740), dark: (0x2B2A3A, 0xE3DFFF),
               KeyMods(shift: 0x6B4BDD, numbers: 0x6B4BDD, ret: 0x6B4BDD)),
        studio("Blossom", light: (0xF6EDEE, 0x3A2B30), dark: (0x3A3034, 0xF4E6E9),
               KeyMods(shift: 0xE57F8E, delete: 0x2D3352, numbers: 0xE57F8E, space: 0xE9A3AE, ret: 0xE57F8E)),

        solo("Ember", 0xE87538),
        solo("Cobalt", 0x4870D8),
        solo("Fern", 0x5B8A52),
        solo("Crimson", 0xCF453A),

        cafe("Mocha", light: (0xF5EFE4, 0x5B4F45), dark: (0x4A4139, 0xF2EADF),
             KeyMods(shift: 0x5B3F31, numbers: 0x5B3F31, ret: 0x5B3F31)),
        cafe("Latte", light: (0xF7F1E7, 0x5E5045), dark: (0x4B4037, 0xF3EBE0),
             KeyMods(shift: 0xC59D78, delete: 0x8A6A51, numbers: 0xC59D78, ret: 0x6A4935)),
        cafe("Matcha", light: (0xF1F4EA, 0x40503A), dark: (0x3A4434, 0xE9F0E1),
             KeyMods(shift: 0x5D8A4D, delete: 0xA8C698, numbers: 0xA8C698, ret: 0x5D8A4D)),
        cafe("Rosé", light: (0xF8F0EE, 0x5A4447), dark: (0x4A3B3E, 0xF6E9EA),
             KeyMods(shift: 0xD77B89, delete: 0x2E3452, numbers: 0xD77B89, space: 0xE6A6B0, ret: 0xD77B89)),

        tide("Indigo", light: (0xDDE5F7, 0x1E3159), dark: (0x232F58, 0xDCE5FF),
             KeyMods(shift: 0x4B6CDA, numbers: 0x4B6CDA, ret: 0x4B6CDA)),
        tide("Lagoon", light: (0xD6EDF3, 0x0F3D49), dark: (0x1B4752, 0xD8F2F8),
             KeyMods(shift: 0x23A0B6, numbers: 0x23A0B6, ret: 0x23A0B6)),
        tide("Glacier", light: (0xEEF3F9, 0x2A3B4F), dark: (0x2C3644, 0xE6EEF7),
             KeyMods(shift: 0x9DBEE6, numbers: 0x9DBEE6, ret: 0x6C9BD6)),
    ]
}
