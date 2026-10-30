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

    /// Heading the theme is listed under in the picker ("" for the basic, non-colour themes).
    var group: String = ""
}

// MARK: - Catalog

enum ThemeCatalog {

    static let defaultID = "native"

    /// Picker order.
    static let all: [ThemeDefinition] = [
        native, transparent, liquidGlass,
        ocean, forest, sunset, aurora, rose, lavender, graphite, midnight, neon,
        t_mint, t_peach, t_butter, t_sky, t_lilac, t_blush,
        t_sage, t_seafoam, t_apricot, t_cottoncandy, t_obsidian, t_charcoal,
        t_espresso, t_deepsea, t_pine, t_wine, t_plum, t_slate,
        t_nightsky, t_cherry, t_tangerine, t_lemon, t_lime, t_emerald,
        t_teal, t_cobalt, t_violet, t_magenta, t_coral, t_bubblegum,
        t_lagoon, t_mangotango, t_berrysmoothie, t_seaandsand, t_fireandice, t_matchalatte,
        t_sunrise, t_typewriter, t_arcade, t_terminal, t_pocketconsole, t_vaporwave,
        t_seventies, t_sepia, t_blueprint, t_moss, t_desert, t_glacier,
        t_volcano, t_autumn, t_cherryblossom, t_coralreef, t_northernlights, t_heather,
        t_stone, t_paper, t_ink, t_silver, t_concrete, t_gold,
        t_rosegold, t_copper, t_champagne
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
            gradientAngle: 90,
            group: "Classic"
        )
    }

    /// Relative brightness (0 black ... 1 white), for picking readable text.
    private static func luminance(_ hex: UInt32) -> Double {
        let c = ThemeRGBA(hex: hex)
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }

    /// A key-colour theme. Text, function keys, pressed states and the colour on the accent follow from the key
    /// colour unless given: dark labels on light keys, white on dark ones; function keys a shade deeper (lighter
    /// on near-black keys).
    private static func make(_ id: String,
                             _ name: String,
                             group: String,
                             key: UInt32,
                             function: UInt32?,
                             text: UInt32?,
                             accent: UInt32,
                             onAccent: UInt32?) -> ThemeDefinition {
        let light = luminance(key) > 0.55
        let label = text.map { ThemeRGBA(hex: $0) } ?? (light ? ThemeRGBA(0.08, 0.08, 0.10, 1) : ThemeRGBA(1, 1, 1, 1))
        let darkLabel = text.map { luminance($0) < 0.5 } ?? light
        let functionFill: ThemeRGBA
        if let function = function {
            functionFill = ThemeRGBA(hex: function)
        } else if luminance(key) < 0.12 {
            functionFill = shade(key, 0.12)
        } else {
            functionFill = shade(key, light ? -0.14 : -0.28)
        }
        let functionHex = function ?? key
        let onAccentColor = onAccent.map { ThemeRGBA(hex: $0) }
            ?? (luminance(accent) > 0.6 ? ThemeRGBA(0.07, 0.07, 0.08, 1) : ThemeRGBA(1, 1, 1, 1))
        return ThemeDefinition(
            id: id,
            name: name,
            kind: .colored,
            isDark: nil,
            key: shade(key, 0),
            function: functionFill,
            keyPressed: shade(key, darkLabel ? -0.15 : 0.22),
            functionPressed: shade(functionHex, darkLabel ? -0.25 : 0.15),
            keyBorder: clear,
            text: label,
            secondaryText: ThemeRGBA(label.r, label.g, label.b, 0.65),
            accent: ThemeRGBA(hex: accent),
            onAccent: onAccentColor,
            popup: shade(key, 0),
            panel: ThemeRGBA(0, 0, 0, 0.08),
            gradientStops: [],
            gradientAngle: 90,
            group: group
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

    // MARK: More key colours

    // Pastel
    static let t_mint = make("mint", "Mint", group: "Pastel", key: 0xBDEFD8, function: nil, text: nil, accent: 0x14A37F, onAccent: nil)
    static let t_peach = make("peach", "Peach", group: "Pastel", key: 0xFFD3B6, function: nil, text: nil, accent: 0xF2723A, onAccent: nil)
    static let t_butter = make("butter", "Butter", group: "Pastel", key: 0xFFF1A8, function: nil, text: nil, accent: 0xE0A800, onAccent: 0x2B2000)
    static let t_sky = make("sky", "Sky", group: "Pastel", key: 0xBFE3FF, function: nil, text: nil, accent: 0x2D8CFF, onAccent: nil)
    static let t_lilac = make("lilac", "Lilac", group: "Pastel", key: 0xE3D0FF, function: nil, text: nil, accent: 0x8E5CF7, onAccent: nil)
    static let t_blush = make("blush", "Blush", group: "Pastel", key: 0xFFD6E0, function: nil, text: nil, accent: 0xE8577E, onAccent: nil)
    static let t_sage = make("sage", "Sage", group: "Pastel", key: 0xCFE0C3, function: nil, text: nil, accent: 0x5B8C51, onAccent: nil)
    static let t_seafoam = make("seafoam", "Seafoam", group: "Pastel", key: 0xB8F2E6, function: nil, text: nil, accent: 0x1F9E89, onAccent: nil)
    static let t_apricot = make("apricot", "Apricot", group: "Pastel", key: 0xFFCFA3, function: nil, text: nil, accent: 0xD9631E, onAccent: nil)
    static let t_cottoncandy = make("cottoncandy", "Cotton Candy", group: "Pastel", key: 0xFFC8E8, function: 0xB8E2FF, text: nil, accent: 0xFF5FA2, onAccent: nil)
    // Dark
    static let t_obsidian = make("obsidian", "Obsidian", group: "Dark", key: 0x1C1C22, function: nil, text: nil, accent: 0x8A7CFF, onAccent: nil)
    static let t_charcoal = make("charcoal", "Charcoal", group: "Dark", key: 0x2E2F33, function: nil, text: nil, accent: 0x30D158, onAccent: nil)
    static let t_espresso = make("espresso", "Espresso", group: "Dark", key: 0x3B2A24, function: nil, text: nil, accent: 0xD9A066, onAccent: nil)
    static let t_deepsea = make("deepsea", "Deep Sea", group: "Dark", key: 0x0F2E4A, function: nil, text: nil, accent: 0x4FC3F7, onAccent: nil)
    static let t_pine = make("pine", "Pine", group: "Dark", key: 0x1E3B2F, function: nil, text: nil, accent: 0x7BD389, onAccent: nil)
    static let t_wine = make("wine", "Wine", group: "Dark", key: 0x4A1C2C, function: nil, text: nil, accent: 0xFF6B8B, onAccent: nil)
    static let t_plum = make("plum", "Plum", group: "Dark", key: 0x3A1F4A, function: nil, text: nil, accent: 0xC792EA, onAccent: nil)
    static let t_slate = make("slate", "Slate", group: "Dark", key: 0x3B4552, function: nil, text: nil, accent: 0x64D2FF, onAccent: nil)
    static let t_nightsky = make("nightsky", "Night Sky", group: "Dark", key: 0x111A33, function: 0x1D2A4D, text: nil, accent: 0xFFD166, onAccent: nil)
    // Vivid
    static let t_cherry = make("cherry", "Cherry", group: "Vivid", key: 0xD72638, function: nil, text: nil, accent: 0xFFFFFF, onAccent: 0xD72638)
    static let t_tangerine = make("tangerine", "Tangerine", group: "Vivid", key: 0xF77F00, function: nil, text: 0xFFFFFF, accent: 0xFFF3B0, onAccent: nil)
    static let t_lemon = make("lemon", "Lemon", group: "Vivid", key: 0xF7D21E, function: nil, text: nil, accent: 0x1E1E1E, onAccent: 0xF7D21E)
    static let t_lime = make("lime", "Lime", group: "Vivid", key: 0x7ED957, function: nil, text: nil, accent: 0x1B5E20, onAccent: nil)
    static let t_emerald = make("emerald", "Emerald", group: "Vivid", key: 0x0F9D58, function: nil, text: nil, accent: 0xFFFFFF, onAccent: 0x0F9D58)
    static let t_teal = make("teal", "Teal", group: "Vivid", key: 0x00897B, function: nil, text: nil, accent: 0xFFE082, onAccent: nil)
    static let t_cobalt = make("cobalt", "Cobalt", group: "Vivid", key: 0x1F4FD8, function: nil, text: nil, accent: 0xFFD60A, onAccent: nil)
    static let t_violet = make("violet", "Violet", group: "Vivid", key: 0x6A3FD6, function: nil, text: nil, accent: 0xFFB3F5, onAccent: nil)
    static let t_magenta = make("magenta", "Magenta", group: "Vivid", key: 0xC2185B, function: nil, text: nil, accent: 0xFFE0EC, onAccent: 0xC2185B)
    static let t_coral = make("coral", "Coral", group: "Vivid", key: 0xFF6F61, function: nil, text: 0xFFFFFF, accent: 0xFFFFFF, onAccent: 0xFF6F61)
    // Two-tone
    static let t_bubblegum = make("bubblegum", "Bubblegum", group: "Two-tone", key: 0xFFB3D9, function: 0xB3E5FF, text: nil, accent: 0xFF4FA3, onAccent: nil)
    static let t_lagoon = make("lagoon", "Lagoon", group: "Two-tone", key: 0x1AA6B7, function: 0x0E5E8C, text: 0xFFFFFF, accent: 0xFFE66D, onAccent: nil)
    static let t_mangotango = make("mangotango", "Mango Tango", group: "Two-tone", key: 0xFFB347, function: 0xFF7043, text: 0x2A1400, accent: 0x6A1B9A, onAccent: nil)
    static let t_berrysmoothie = make("berrysmoothie", "Berry Smoothie", group: "Two-tone", key: 0x9C27B0, function: 0xE91E63, text: 0xFFFFFF, accent: 0xFFE0F0, onAccent: 0x9C27B0)
    static let t_seaandsand = make("seaandsand", "Sea & Sand", group: "Two-tone", key: 0xF4E1C1, function: 0x9ED6D3, text: nil, accent: 0x2A7F8F, onAccent: nil)
    static let t_fireandice = make("fireandice", "Fire & Ice", group: "Two-tone", key: 0x3E7CB1, function: 0xC0392B, text: 0xFFFFFF, accent: 0xFFFFFF, onAccent: 0x3E7CB1)
    static let t_matchalatte = make("matchalatte", "Matcha Latte", group: "Two-tone", key: 0xD8E2C4, function: 0xC9B79C, text: nil, accent: 0x5E7D3B, onAccent: nil)
    static let t_sunrise = make("sunrise", "Sunrise", group: "Two-tone", key: 0xFFD27F, function: 0xFF8C69, text: 0x2A1400, accent: 0xD7263D, onAccent: nil)
    // Retro
    static let t_typewriter = make("typewriter", "Typewriter", group: "Retro", key: 0xEDE6D6, function: 0xCFC6B0, text: 0x2B2B2B, accent: 0xB23A3A, onAccent: nil)
    static let t_arcade = make("arcade", "Arcade", group: "Retro", key: 0x1A1A2E, function: 0x16213E, text: 0x00FFC6, accent: 0xFF2E88, onAccent: nil)
    static let t_terminal = make("terminal", "Terminal", group: "Retro", key: 0x0B0F0B, function: 0x101A10, text: 0x33FF66, accent: 0x33FF66, onAccent: 0x002B0D)
    static let t_pocketconsole = make("pocketconsole", "Pocket Console", group: "Retro", key: 0x9BBC0F, function: 0x8BAC0F, text: 0x0F380F, accent: 0x306230, onAccent: 0x9BBC0F)
    static let t_vaporwave = make("vaporwave", "Vaporwave", group: "Retro", key: 0xFF71CE, function: 0x01CDFE, text: 0x2D0B3A, accent: 0xB967FF, onAccent: nil)
    static let t_seventies = make("seventies", "Seventies", group: "Retro", key: 0xC0671F, function: 0x7A3E12, text: 0xFFF3DC, accent: 0xF2C14E, onAccent: nil)
    static let t_sepia = make("sepia", "Sepia", group: "Retro", key: 0x704214, function: 0x4E2E0E, text: 0xF5E6CC, accent: 0xE3B778, onAccent: nil)
    static let t_blueprint = make("blueprint", "Blueprint", group: "Retro", key: 0x1E4D8C, function: 0x163A6A, text: 0xE8F1FF, accent: 0xFFFFFF, onAccent: 0x1E4D8C)
    // Nature
    static let t_moss = make("moss", "Moss", group: "Nature", key: 0x5E7D3B, function: nil, text: nil, accent: 0xD4E157, onAccent: nil)
    static let t_desert = make("desert", "Desert", group: "Nature", key: 0xD9A066, function: nil, text: nil, accent: 0x8C4A1E, onAccent: nil)
    static let t_glacier = make("glacier", "Glacier", group: "Nature", key: 0xD6F0F7, function: nil, text: nil, accent: 0x2B88B5, onAccent: nil)
    static let t_volcano = make("volcano", "Volcano", group: "Nature", key: 0x2B2B2B, function: 0x8B1E1E, text: 0xFFFFFF, accent: 0xFF5722, onAccent: nil)
    static let t_autumn = make("autumn", "Autumn", group: "Nature", key: 0xB5541F, function: 0x7A2E10, text: 0xFFFFFF, accent: 0xF4C430, onAccent: nil)
    static let t_cherryblossom = make("cherryblossom", "Cherry Blossom", group: "Nature", key: 0xFDE2E4, function: 0xF7C5CC, text: nil, accent: 0xD45079, onAccent: nil)
    static let t_coralreef = make("coralreef", "Coral Reef", group: "Nature", key: 0xFF8C7A, function: 0x2EC4B6, text: 0x10222E, accent: 0x0B3954, onAccent: nil)
    static let t_northernlights = make("northernlights", "Northern Lights", group: "Nature", key: 0x0B1D2A, function: 0x123B3A, text: 0xC8FFF0, accent: 0x5CFFB0, onAccent: nil)
    static let t_heather = make("heather", "Heather", group: "Nature", key: 0xB79FC9, function: nil, text: nil, accent: 0x5B3A7A, onAccent: nil)
    static let t_stone = make("stone", "Stone", group: "Nature", key: 0xA7A39C, function: nil, text: nil, accent: 0x3F3D39, onAccent: nil)
    // Metal & mono
    static let t_paper = make("paper", "Paper", group: "Metal & mono", key: 0xFAFAF7, function: 0xE6E4DE, text: 0x1A1A1A, accent: 0x1A1A1A, onAccent: nil)
    static let t_ink = make("ink", "Ink", group: "Metal & mono", key: 0x121212, function: 0x262626, text: 0xFFFFFF, accent: 0xFFFFFF, onAccent: 0x121212)
    static let t_silver = make("silver", "Silver", group: "Metal & mono", key: 0xC9CCD1, function: 0xA9ADB4, text: nil, accent: 0x3A3D42, onAccent: nil)
    static let t_concrete = make("concrete", "Concrete", group: "Metal & mono", key: 0x8E9196, function: 0x6E7176, text: 0x111111, accent: 0x2C2E31, onAccent: nil)
    static let t_gold = make("gold", "Gold", group: "Metal & mono", key: 0xD4AF37, function: 0xA8862B, text: 0x2B2108, accent: 0x2B2108, onAccent: 0xD4AF37)
    static let t_rosegold = make("rosegold", "Rose Gold", group: "Metal & mono", key: 0xE8B4A6, function: 0xC98B7A, text: nil, accent: 0x8C4A3E, onAccent: nil)
    static let t_copper = make("copper", "Copper", group: "Metal & mono", key: 0xB87333, function: 0x8A5426, text: 0xFFFFFF, accent: 0xFFE0C2, onAccent: nil)
    static let t_champagne = make("champagne", "Champagne", group: "Metal & mono", key: 0xF2E2C4, function: nil, text: nil, accent: 0xA67C3D, onAccent: nil)
}
