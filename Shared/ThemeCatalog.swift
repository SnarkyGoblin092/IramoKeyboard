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
    /// How a keycap theme's caps are built.
    var profile: KeycapProfile = .dished

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

/// How a 3D keycap is built: a shell (the key's whole shape, a shade off its colour, lit from above) with the face
/// set into it. KeyView and the app's previews (ThemeLook) both draw from this.
enum KeycapProfile: String, Hashable {
    /// A flat, lighter top face sitting high on a deeper shell (typewriter-style caps).
    case sculpted
    /// A softly rounded, concave dish set into a convex shell.
    case dished
    /// A shell showing all round a face with an outline.
    case ringed

    /// How far the face sits in from the shell's top, sides and bottom, for a key of this height.
    func insets(height: CGFloat) -> (top: CGFloat, side: CGFloat, bottom: CGFloat) {
        let scale = min(1.2, max(0.7, height / 42))
        switch self {
        case .sculpted: return (1.5 * scale, 2.5 * scale, 5 * scale)
        case .dished: return (2 * scale, 3.5 * scale, 6 * scale)
        case .ringed: return (2.5 * scale, 2.5 * scale, 4 * scale)
        }
    }

    /// How far the face drops into the shell while the key is held.
    static func pressDrop(height: CGFloat) -> CGFloat { return min(2, max(1, height * 0.035)) }

    /// How much darker the shell is than the face (negative: lighter).
    func shellShade(dark: Bool) -> Double {
        switch self {
        case .sculpted: return dark ? 0.32 : 0.14
        case .dished: return dark ? -0.06 : 0.05
        case .ringed: return dark ? -0.08 : 0.1
        }
    }

    /// The light over the shell, top to bottom: white at a positive strength, black at a negative one.
    func shellLight(dark: Bool) -> (top: Double, bottom: Double) {
        switch self {
        case .sculpted: return dark ? (0.10, -0.25) : (0.25, -0.10)
        case .dished: return dark ? (0.14, -0.30) : (0.30, -0.14)
        case .ringed: return dark ? (0.10, -0.25) : (0.30, -0.10)
        }
    }

    /// The light over the face, top to bottom (a dish is shaded at the top and lit at the bottom).
    func faceLight(dark: Bool) -> (top: Double, bottom: Double) {
        switch self {
        case .sculpted: return dark ? (0.06, 0) : (0.12, 0)
        case .dished: return dark ? (-0.18, 0.04) : (-0.06, 0.10)
        case .ringed: return dark ? (0.05, 0) : (0.15, 0)
        }
    }

    /// The face's corner radius for a key with this one.
    func faceRadius(keyRadius: CGFloat, faceHeight: CGFloat) -> CGFloat {
        switch self {
        case .dished: return min(faceHeight / 2, keyRadius + 3)
        case .sculpted, .ringed: return max(2, keyRadius - 2)
        }
    }

    /// The soft shadow under the whole key (opacity, light and dark mode).
    static func contactShadow(dark: Bool) -> Double { return dark ? 0.5 : 0.2 }
}

/// One modifier's own look in a keycap theme: its fill, its label (nil: dark or white by the fill) and an outline
/// ring round its face (nil: none).
struct RoleTone: Hashable {
    let fill: ThemeRGBA
    let label: ThemeRGBA?
    let ring: ThemeRGBA?

    init(_ fill: UInt32, label: UInt32? = nil, ring: UInt32? = nil) {
        self.fill = ThemeRGBA(hex: fill)
        self.label = label.map { ThemeRGBA(hex: $0) }
        self.ring = ring.map { ThemeRGBA(hex: $0) }
    }
}

/// A keycap theme's colours in one appearance (light or dark).
struct ThemeTones: Hashable {
    /// The letter keys and their labels.
    let key: ThemeRGBA
    let text: ThemeRGBA
    /// The plain function keys (emoji, and the modifiers without a colour of their own).
    let function: ThemeRGBA
    /// Set by ThemeColors: these are the dark mode colours.
    fileprivate(set) var isDark = false
    /// The modifiers with a look of their own.
    let roles: [KeyRole: RoleTone]
    /// Letter labels and rings coloured by where the key sits (left to right), when not empty.
    let letterTints: [ThemeRGBA]
    /// An outline round the plain keys' faces (nil: none).
    let keyRing: ThemeRGBA?

    /// `key`/`text`: the letter keys. The modifiers left out of `mods` take the plain function key colour (the
    /// letter colour, a shade darker in light mode and lighter in dark mode).
    init(key: UInt32, text: UInt32, dark: Bool, mods: KeyMods) {
        let key = ThemeRGBA(hex: key)
        self.key = key
        self.text = ThemeRGBA(hex: text)
        self.function = dark ? key.mixed(with: .white, 0.08) : key.mixed(with: .black, 0.1)
        self.isDark = dark
        var roles: [KeyRole: RoleTone] = [.ret: RoleTone(mods.ret)]
        if let shift = mods.shift { roles[.shift] = RoleTone(shift) }
        if let delete = mods.delete { roles[.delete] = RoleTone(delete) }
        if let numbers = mods.numbers { roles[.numbers] = RoleTone(numbers) }
        if let space = mods.space { roles[.space] = RoleTone(space) }
        self.roles = roles
        self.letterTints = []
        self.keyRing = nil
    }

    /// Every colour given (the Signature themes). `function` nil: the letter colour.
    init(key: UInt32, text: UInt32, function: UInt32? = nil, roles: [KeyRole: RoleTone],
         letterTints: [UInt32] = [], keyRing: UInt32? = nil) {
        self.key = ThemeRGBA(hex: key)
        self.text = ThemeRGBA(hex: text)
        self.function = ThemeRGBA(hex: function ?? key)
        self.roles = roles
        self.letterTints = letterTints.map { ThemeRGBA(hex: $0) }
        self.keyRing = keyRing.map { ThemeRGBA(hex: $0) }
    }

    /// The return key's colour (the theme's accent).
    var ret: ThemeRGBA { return fill(.ret) }

    func fill(_ role: KeyRole) -> ThemeRGBA {
        switch role {
        case .letter: return key
        case .function: return function
        default: return roles[role]?.fill ?? (role == .space ? key : function)
        }
    }

    /// The label on a key: its own, the theme's text on the plain keys, else dark or white by how light the key is.
    func label(_ role: KeyRole) -> ThemeRGBA {
        guard let own = roles[role] else { return text }
        if let label = own.label { return label }
        return own.fill.luminance > 0.6 ? ThemeRGBA(hex: 0x1E1E1E) : .white
    }

    /// The outline round a key's face, if it has one.
    func ring(_ role: KeyRole) -> ThemeRGBA? {
        if let own = roles[role] { return own.ring }
        return keyRing
    }

    /// Words on the system keyboard backdrop (the suggestion bar): the letters' colour while it reads there, else
    /// near-black on the light backdrop and near-white on the dark one.
    var stripText: ThemeRGBA {
        if isDark { return text.luminance < 0.45 ? ThemeRGBA(hex: 0xF2F2F2) : text }
        return text.luminance > 0.6 ? ThemeRGBA(hex: 0x1E1E1E) : text
    }

    /// Which tint a letter takes: the columns of the QWERTY rows, two at a time.
    private static let tintColumns: [Character: Int] = {
        var map: [Character: Int] = [:]
        for (index, letters) in ["qwaszx", "erdfc", "tyghvb", "uijkn", "oplm"].enumerated() {
            for letter in letters { map[letter] = index }
        }
        return map
    }()

    /// A letter key's own colour (its label, and its ring at a lighter strength), if the theme tints letters.
    func letterTint(_ title: String) -> ThemeRGBA? {
        // Punctuation (and letters outside the QWERTY columns) stays in the plain colour.
        guard !letterTints.isEmpty, title.count == 1, let first = title.lowercased().first,
              let index = ThemeTones.tintColumns[first] else { return nil }
        return letterTints[index % letterTints.count]
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

    init(light: ThemeTones, dark: ThemeTones) {
        var darkTones = dark
        darkTones.isDark = true
        self.light = light
        self.dark = darkTones
    }

    func tones(dark isDark: Bool) -> ThemeTones { return isDark ? dark : light }
}

// MARK: - Catalog

enum ThemeCatalog {

    static let defaultID = "native"

    /// The themes, in picker order.
    static let all: [ThemeDefinition] = [native, transparent, liquidGlass] + signatureThemes + keycapThemes

    /// The keycap families, in picker order.
    static let families = ["Signature", "Arcade", "Studio", "Solo", "Café", "Tide"]

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
                                  profile: KeycapProfile = .dished,
                                  light: (UInt32, UInt32), dark: (UInt32, UInt32), mods: KeyMods) -> ThemeDefinition {
        var style = SystemStyle()
        style.roundness = roundness
        style.surface = "flat"   // the profile lights the cap
        style.border = "none"
        let id = "\(family)-\(variant)".lowercased().folding(options: .diacriticInsensitive, locale: nil)
        return ThemeDefinition(id: id, name: "\(family) \(variant)", kind: .keycap,
                               summary: "\(variant) 3D keycaps", systemStyle: style,
                               colors: ThemeColors(light: ThemeTones(key: light.0, text: light.1, dark: false, mods: mods),
                                                   dark: ThemeTones(key: dark.0, text: dark.1, dark: true, mods: mods)),
                               family: family, font: font, profile: profile)
    }

    /// Cream caps with candy-coloured modifiers.
    private static func arcade(_ variant: String, light: (UInt32, UInt32), dark: (UInt32, UInt32),
                               _ mods: KeyMods) -> ThemeDefinition {
        return colourway("Arcade", variant, font: "mono", roundness: 0.28, profile: .sculpted,
                         light: light, dark: dark, mods: mods)
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
        return colourway("Café", variant, font: "rounded", roundness: 0.42, profile: .sculpted,
                         light: light, dark: dark, mods: mods)
    }

    /// Caps tinted through in one colour.
    private static func tide(_ variant: String, light: (UInt32, UInt32), dark: (UInt32, UInt32),
                             _ mods: KeyMods) -> ThemeDefinition {
        return colourway("Tide", variant, font: nil, roundness: 0.36, light: light, dark: dark, mods: mods)
    }

    /// A Signature theme: keycaps in a case of their own colour, every key's colour given for both modes.
    private static func signature(_ id: String, _ name: String, _ summary: String, font: String? = nil,
                                  profile: KeycapProfile = .dished, roundness: Double,
                                  light: ThemeTones, dark: ThemeTones) -> ThemeDefinition {
        var style = SystemStyle()
        style.roundness = roundness
        style.surface = "flat"   // the profile lights the cap
        style.border = "none"
        return ThemeDefinition(id: "signature-\(id)", name: name, kind: .keycap, summary: summary, systemStyle: style,
                               colors: ThemeColors(light: light, dark: dark), family: "Signature", font: font,
                               profile: profile)
    }

    static let signatureThemes: [ThemeDefinition] = [
        signature("typist", "Typist", "Sculpted cream caps with candy modifiers", font: "mono", profile: .sculpted,
                  roundness: 0.24,
                  light: ThemeTones(key: 0xF2EEDB, text: 0x1F1F1F, roles: [
                    .shift: RoleTone(0xD3434A, label: 0x1A1A1A), .delete: RoleTone(0xDA7637, label: 0x2A1A10),
                    .numbers: RoleTone(0xE2CD5E, label: 0x2A2A1A), .ret: RoleTone(0x4F9BE2, label: 0x10243A)]),
                  dark: ThemeTones(key: 0x3E3C3A, text: 0xECE8DE, roles: [
                    .shift: RoleTone(0xD3434A, label: 0xFFFFFF), .delete: RoleTone(0xC96F36, label: 0x1E1E1E),
                    .numbers: RoleTone(0xC9B550, label: 0x1E1E1E), .ret: RoleTone(0x4A90D6, label: 0x101820)])),
        signature("nebula", "Nebula", "Teal, mustard and coral on soft caps", roundness: 0.32,
                  light: ThemeTones(key: 0xF3F3F1, text: 0x46464A, roles: [
                    .shift: RoleTone(0x6DBFA0, label: 0x17362B), .numbers: RoleTone(0x6DBFA0, label: 0x1E4A3A),
                    .delete: RoleTone(0xD4B649, label: 0x3A3216), .ret: RoleTone(0xD25E3E, label: 0xFFFFFF)]),
                  dark: ThemeTones(key: 0x3A3A3D, text: 0xD6D6D8, roles: [
                    .shift: RoleTone(0x6FCBA8, label: 0x1D3B30), .numbers: RoleTone(0x6FCBA8, label: 0x1D3B30),
                    .delete: RoleTone(0xD9C04B, label: 0x3A3216), .ret: RoleTone(0xD9654A, label: 0x3A1A12)])),
        signature("amethyst", "Amethyst", "Graphite caps with violet modifiers", roundness: 0.3,
                  light: ThemeTones(key: 0x4B4C51, text: 0xEEEEEE, roles: [
                    .shift: RoleTone(0x5B42D8), .delete: RoleTone(0x5B42D8),
                    .numbers: RoleTone(0x5B42D8), .ret: RoleTone(0x5B42D8)]),
                  dark: ThemeTones(key: 0x3A3B40, text: 0xE6E6E8, roles: [
                    .shift: RoleTone(0x5B42D8), .delete: RoleTone(0x5B42D8),
                    .numbers: RoleTone(0x5B42D8), .ret: RoleTone(0x5B42D8)])),
        signature("orchid", "Orchid", "Teal legends with violet modifiers", roundness: 0.3,
                  light: ThemeTones(key: 0xF3F2F7, text: 0x2E8F7C, roles: [
                    .shift: RoleTone(0x7B60DC, label: 0xD9FFF5), .numbers: RoleTone(0x7B60DC, label: 0xD9FFF5),
                    .ret: RoleTone(0x7B60DC, label: 0xD9FFF5)]),
                  dark: ThemeTones(key: 0x2D2C34, text: 0x86D9C5, roles: [
                    .shift: RoleTone(0x6B50D0, label: 0x9BE6D3), .numbers: RoleTone(0x6B50D0, label: 0x9BE6D3),
                    .ret: RoleTone(0x6B50D0, label: 0x9BE6D3)])),
        signature("blaze", "Blaze", "Graphite caps with orange modifiers", roundness: 0.3,
                  light: ThemeTones(key: 0x45474D, text: 0xF0F0F0, roles: [
                    .shift: RoleTone(0xE5703A), .numbers: RoleTone(0xE5703A), .ret: RoleTone(0xE5703A),
                    .delete: RoleTone(0xF3F3F3, label: 0x4A4A4A)]),
                  dark: ThemeTones(key: 0x3A3B3F, text: 0xEDEDED, roles: [
                    .shift: RoleTone(0xE5703A), .numbers: RoleTone(0xE5703A), .ret: RoleTone(0xE5703A),
                    .delete: RoleTone(0xE8E8E8, label: 0x3A3A3A)])),
        signature("rosewood", "Rosewood", "Blush caps with a navy delete", roundness: 0.3,
                  light: ThemeTones(key: 0xF6F0EF, text: 0x3A3A4A, roles: [
                    .shift: RoleTone(0xE2808D, label: 0x2E3452), .numbers: RoleTone(0xE2808D, label: 0x7A2836),
                    .space: RoleTone(0xE2808D), .ret: RoleTone(0xE2808D, label: 0x2E3452),
                    .delete: RoleTone(0x2E3452, label: 0xFFFFFF)]),
                  dark: ThemeTones(key: 0x47393E, text: 0xF3E7E9, roles: [
                    .shift: RoleTone(0xD9707E, label: 0x1E2238), .numbers: RoleTone(0xD9707E, label: 0x3A1018),
                    .space: RoleTone(0xC96877), .ret: RoleTone(0xD9707E, label: 0x1E2238),
                    .delete: RoleTone(0x2B3150, label: 0xFFFFFF)])),
        signature("cocoa", "Cocoa", "Cream caps with chocolate modifiers", roundness: 0.32,
                  light: ThemeTones(key: 0xF2EDE2, text: 0x7B7166, roles: [
                    .shift: RoleTone(0x5C3F30), .numbers: RoleTone(0x5C3F30), .ret: RoleTone(0x5C3F30)]),
                  dark: ThemeTones(key: 0x4A403A, text: 0xE8DFD3, roles: [
                    .shift: RoleTone(0x7A5442), .numbers: RoleTone(0x7A5442), .ret: RoleTone(0x7A5442)])),
        signature("mojito", "Mojito", "Cream caps with sage modifiers", roundness: 0.32,
                  light: ThemeTones(key: 0xF3F3E9, text: 0x576C4C, roles: [
                    .shift: RoleTone(0x5D8D4C), .numbers: RoleTone(0xA4C791, label: 0x4C6640),
                    .delete: RoleTone(0xA4C791, label: 0x3E5534), .ret: RoleTone(0xA4C791, label: 0x3E5534)]),
                  dark: ThemeTones(key: 0x36422F, text: 0xDCE9CE, roles: [
                    .shift: RoleTone(0x6E9F5B), .numbers: RoleTone(0x59744C, label: 0xE3EFD9),
                    .delete: RoleTone(0x59744C, label: 0xE3EFD9), .ret: RoleTone(0x59744C, label: 0xE3EFD9)])),
        signature("rally", "Rally", "Teal, a yellow space bar and a red return", roundness: 0.32,
                  light: ThemeTones(key: 0xF3F3F3, text: 0x3A3A3C, roles: [
                    .shift: RoleTone(0x5FC0A4, label: 0xFFFFFF), .numbers: RoleTone(0x5FC0A4, label: 0x17362D),
                    .space: RoleTone(0xE8C552), .ret: RoleTone(0xDF5646, label: 0xFFFFFF)]),
                  dark: ThemeTones(key: 0x38383B, text: 0xE2E2E2, roles: [
                    .shift: RoleTone(0x6ECDB2, label: 0xFFFFFF), .numbers: RoleTone(0x6ECDB2, label: 0x1E3D35),
                    .space: RoleTone(0xE6C24F), .ret: RoleTone(0xE2594A, label: 0xFFFFFF)])),
        signature("electro", "Electro", "Lime legends and lime modifiers", roundness: 0.3,
                  light: ThemeTones(key: 0xF4F6EC, text: 0x5E7B1F, roles: [
                    .shift: RoleTone(0xB4D94E, label: 0x1E2416), .numbers: RoleTone(0xB4D94E, label: 0x1E2416),
                    .ret: RoleTone(0xB4D94E, label: 0x1E2416), .delete: RoleTone(0xB9BCB5, label: 0x2E2E2E)]),
                  dark: ThemeTones(key: 0x33352F, text: 0xCBEA6C, roles: [
                    .shift: RoleTone(0xC0E15B, label: 0x1E2416), .numbers: RoleTone(0xC0E15B, label: 0x1E2416),
                    .ret: RoleTone(0xC0E15B, label: 0x1E2416), .delete: RoleTone(0x9C9E9A, label: 0x2E2E2E)])),
        signature("starlit", "Starlit", "Graphite caps with indigo modifiers", roundness: 0.3,
                  light: ThemeTones(key: 0xF3F5FB, text: 0x2C3B66, roles: [
                    .shift: RoleTone(0x4A78E6), .numbers: RoleTone(0x4A78E6), .ret: RoleTone(0x4A78E6)]),
                  dark: ThemeTones(key: 0x2F3035, text: 0xE8E8E8, roles: [
                    .shift: RoleTone(0x3E6EE0), .numbers: RoleTone(0x3E6EE0), .ret: RoleTone(0x3E6EE0)])),
        signature("riptide", "Riptide", "Blue on blue with ice-blue modifiers", roundness: 0.32,
                  light: ThemeTones(key: 0xEAF1FC, text: 0x1F407B, roles: [
                    .shift: RoleTone(0x2F64C3), .numbers: RoleTone(0x7FA8DA, label: 0xFFFFFF),
                    .delete: RoleTone(0x7FA8DA, label: 0xFFFFFF), .ret: RoleTone(0x7FA8DA, label: 0xFFFFFF)]),
                  dark: ThemeTones(key: 0x2A4E95, text: 0xD5E2F8, roles: [
                    .shift: RoleTone(0xA9CCF1, label: 0x1D3A6A), .numbers: RoleTone(0x80A9DB, label: 0xE2ECFA),
                    .delete: RoleTone(0x80A9DB, label: 0xE2ECFA), .ret: RoleTone(0x80A9DB, label: 0xE2ECFA)])),
        signature("prism", "Prism", "Outlined pill keys in rainbow pastels", profile: .ringed, roundness: 0.6,
                  light: ThemeTones(key: 0xEBECEF, text: 0x6B6B70, roles: [
                    .shift: RoleTone(0x4D7BC4, label: 0xFFFFFF),
                    .delete: RoleTone(0xEBECEF, label: 0xC0565E, ring: 0xD9878C),
                    .numbers: RoleTone(0xEBECEF, label: 0x8E7A3E, ring: 0xD7C17E),
                    .ret: RoleTone(0xEBECEF, label: 0x4F8058, ring: 0x9CC3A1)],
                    letterTints: [0xC8708A, 0xBFA046, 0x5E9A63, 0x5B87C2, 0x9A72B5], keyRing: 0xC9CACF),
                  dark: ThemeTones(key: 0x2F3035, text: 0xC9C9CF, roles: [
                    .shift: RoleTone(0x5B88D4, label: 0xFFFFFF),
                    .delete: RoleTone(0x2F3035, label: 0xE8787F, ring: 0xB85C63),
                    .numbers: RoleTone(0x2F3035, label: 0xD9BC62, ring: 0x9C8743),
                    .ret: RoleTone(0x2F3035, label: 0x7DBE84, ring: 0x5F9566)],
                    letterTints: [0xE58FA8, 0xD9BC62, 0x7DBE84, 0x7FA7E0, 0xB996D1], keyRing: 0x4A4B51)),

        // More colourways of the sculpted caps.
        signature("typist-dusk", "Typist Dusk", "Sculpted cream caps with plum, rose and teal", font: "mono",
                  profile: .sculpted, roundness: 0.24,
                  light: ThemeTones(key: 0xF2EEDB, text: 0x1F1F1F, roles: [
                    .shift: RoleTone(0x8E4FB0), .delete: RoleTone(0xD9577A),
                    .numbers: RoleTone(0xE8A23A, label: 0x2A1A08), .ret: RoleTone(0x2FA9A3)]),
                  dark: ThemeTones(key: 0x3E3C3A, text: 0xECE8DE, roles: [
                    .shift: RoleTone(0x8E4FB0), .delete: RoleTone(0xD9577A),
                    .numbers: RoleTone(0xE0A040, label: 0x2A1A08), .ret: RoleTone(0x2FA9A3)])),
        signature("typist-sage", "Typist Sage", "Sculpted caps in sage, clay and slate", font: "mono",
                  profile: .sculpted, roundness: 0.24,
                  light: ThemeTones(key: 0xEFEFE4, text: 0x2A2E26, roles: [
                    .shift: RoleTone(0x6E8F5E), .delete: RoleTone(0xC98B4A),
                    .numbers: RoleTone(0xD8C27A, label: 0x2A2410), .ret: RoleTone(0x4C7A8F)]),
                  dark: ThemeTones(key: 0x3A3D37, text: 0xE8EBE0, roles: [
                    .shift: RoleTone(0x6E8F5E), .delete: RoleTone(0xB97E42),
                    .numbers: RoleTone(0xC9B46E, label: 0x2A2410), .ret: RoleTone(0x4C7A8F)])),
        signature("typist-marine", "Typist Marine", "Sculpted caps in navy and gold", font: "mono",
                  profile: .sculpted, roundness: 0.24,
                  light: ThemeTones(key: 0xEEF1F6, text: 0x1E2440, roles: [
                    .shift: RoleTone(0x2F4A8A), .delete: RoleTone(0x6F8FE0),
                    .numbers: RoleTone(0x9DB4E8, label: 0x1E2440), .ret: RoleTone(0xE0A640, label: 0x2A1A08)]),
                  dark: ThemeTones(key: 0x2F3442, text: 0xE3E8F5, roles: [
                    .shift: RoleTone(0x3A5AA6), .delete: RoleTone(0x6F8FE0),
                    .numbers: RoleTone(0x8FA6DC, label: 0x1E2440), .ret: RoleTone(0xE0A640, label: 0x2A1A08)])),
        signature("typist-cherry", "Typist Cherry", "Sculpted ivory caps, cherry red and ink", font: "mono",
                  profile: .sculpted, roundness: 0.24,
                  light: ThemeTones(key: 0xF6F1EA, text: 0x2A1E1E, roles: [
                    .shift: RoleTone(0xC8323A), .numbers: RoleTone(0xC8323A),
                    .delete: RoleTone(0x2A2A2E), .ret: RoleTone(0x2A2A2E)]),
                  dark: ThemeTones(key: 0x3A3434, text: 0xF0E8E4, roles: [
                    .shift: RoleTone(0xC8323A), .numbers: RoleTone(0xC8323A),
                    .delete: RoleTone(0x1F1F22), .ret: RoleTone(0x1F1F22)])),

        // More colourways of the dished caps.
        signature("berry", "Berry", "Soft caps in magenta, violet and coral", roundness: 0.32,
                  light: ThemeTones(key: 0xF4F2F5, text: 0x3E3A44, roles: [
                    .shift: RoleTone(0xC25B9E), .numbers: RoleTone(0xC25B9E),
                    .delete: RoleTone(0x7A6FD6), .ret: RoleTone(0xF07C6A)]),
                  dark: ThemeTones(key: 0x37353B, text: 0xDEDAE4, roles: [
                    .shift: RoleTone(0xC25B9E), .numbers: RoleTone(0xC25B9E),
                    .delete: RoleTone(0x7A6FD6), .ret: RoleTone(0xF07C6A)])),
        signature("sunrise", "Sunrise", "Warm caps in coral, amber and sun", roundness: 0.32,
                  light: ThemeTones(key: 0xF6F3EF, text: 0x4A3F38, roles: [
                    .shift: RoleTone(0xFF8A65), .numbers: RoleTone(0xFFB34D, label: 0x3A2208),
                    .delete: RoleTone(0xF4D06F, label: 0x3A2E08), .ret: RoleTone(0xE8505B)]),
                  dark: ThemeTones(key: 0x3A3633, text: 0xEDE6E0, roles: [
                    .shift: RoleTone(0xF07A55), .numbers: RoleTone(0xF0A440, label: 0x3A2208),
                    .delete: RoleTone(0xE4C060, label: 0x3A2E08), .ret: RoleTone(0xE0484F)])),
        signature("carbon", "Carbon", "Graphite caps with racing red", roundness: 0.3,
                  light: ThemeTones(key: 0x3D3E42, text: 0xEDEDED, roles: [
                    .shift: RoleTone(0xD93A3A), .numbers: RoleTone(0xD93A3A), .ret: RoleTone(0xD93A3A),
                    .delete: RoleTone(0xE9E9E9, label: 0x3A3A3A)]),
                  dark: ThemeTones(key: 0x33343A, text: 0xE8E8E8, roles: [
                    .shift: RoleTone(0xD93A3A), .numbers: RoleTone(0xD93A3A), .ret: RoleTone(0xD93A3A),
                    .delete: RoleTone(0xDADADA, label: 0x3A3A3A)])),
        signature("sky", "Sky", "Pale caps with sky-blue modifiers", roundness: 0.32,
                  light: ThemeTones(key: 0xF5F8FC, text: 0x2E3E55, roles: [
                    .shift: RoleTone(0x5AA9E6), .numbers: RoleTone(0x5AA9E6), .ret: RoleTone(0x5AA9E6),
                    .delete: RoleTone(0xC9D9EC, label: 0x2E3E55)]),
                  dark: ThemeTones(key: 0x323A45, text: 0xE3ECF6, roles: [
                    .shift: RoleTone(0x4F9BD8), .numbers: RoleTone(0x4F9BD8), .ret: RoleTone(0x4F9BD8),
                    .delete: RoleTone(0x56657A, label: 0xE3ECF6)])),
        signature("ink", "Ink", "White caps with ink-black modifiers", roundness: 0.32,
                  light: ThemeTones(key: 0xFAFAFA, text: 0x222222, roles: [
                    .shift: RoleTone(0x222222), .numbers: RoleTone(0x222222), .ret: RoleTone(0x222222),
                    .delete: RoleTone(0xD9D9D9, label: 0x222222)]),
                  dark: ThemeTones(key: 0x3A3A3C, text: 0xF2F2F2, roles: [
                    .shift: RoleTone(0xF2F2F2, label: 0x1E1E1E), .numbers: RoleTone(0xF2F2F2, label: 0x1E1E1E),
                    .ret: RoleTone(0xF2F2F2, label: 0x1E1E1E), .delete: RoleTone(0x59595D)])),
        signature("peach", "Peach", "Cream caps with peach and apricot", roundness: 0.34,
                  light: ThemeTones(key: 0xFFF6F0, text: 0x5A4038, roles: [
                    .shift: RoleTone(0xF7A983, label: 0x3A1E10), .numbers: RoleTone(0xF7A983, label: 0x3A1E10),
                    .delete: RoleTone(0xE9C9B8, label: 0x5A4038), .ret: RoleTone(0xF28B6E)]),
                  dark: ThemeTones(key: 0x45383A, text: 0xF6E6DE, roles: [
                    .shift: RoleTone(0xF0A07A, label: 0x3A1E10), .numbers: RoleTone(0xF0A07A, label: 0x3A1E10),
                    .delete: RoleTone(0x6A5452, label: 0xF6E6DE), .ret: RoleTone(0xE8805F)])),
        signature("haze", "Haze", "Lilac caps with a lavender wash", roundness: 0.34,
                  light: ThemeTones(key: 0xF5F3FA, text: 0x3D3654, roles: [
                    .shift: RoleTone(0xA48BE0), .numbers: RoleTone(0xA48BE0), .ret: RoleTone(0xA48BE0),
                    .delete: RoleTone(0xD9D0F0, label: 0x3D3654), .space: RoleTone(0xE6E0F6)]),
                  dark: ThemeTones(key: 0x37334A, text: 0xECE6FA, roles: [
                    .shift: RoleTone(0x9A80DA), .numbers: RoleTone(0x9A80DA), .ret: RoleTone(0x9A80DA),
                    .delete: RoleTone(0x4E4866, label: 0xECE6FA), .space: RoleTone(0x433E58)])),

        // More colourways of the outlined caps.
        signature("prism-sorbet", "Prism Sorbet", "Outlined pill keys in bright sorbet colours", profile: .ringed,
                  roundness: 0.6,
                  light: ThemeTones(key: 0xF2F0F0, text: 0x6B6060, roles: [
                    .shift: RoleTone(0xE86A8A),
                    .delete: RoleTone(0xF2F0F0, label: 0xD9505F, ring: 0xE86A8A),
                    .numbers: RoleTone(0xF2F0F0, label: 0x9A7A1E, ring: 0xE0B83C),
                    .ret: RoleTone(0xF2F0F0, label: 0x2F8063, ring: 0x3FB08A)],
                    letterTints: [0xE86A8A, 0xF29A4A, 0xC9A12A, 0x3FB08A, 0x5E8FE0], keyRing: 0xD2CDCD),
                  dark: ThemeTones(key: 0x343032, text: 0xD8D0D0, roles: [
                    .shift: RoleTone(0xFF8FA8, label: 0x2A1018),
                    .delete: RoleTone(0x343032, label: 0xFF8FA8, ring: 0xC26A78),
                    .numbers: RoleTone(0x343032, label: 0xF2D06A, ring: 0xA8904A),
                    .ret: RoleTone(0x343032, label: 0x6FD3AE, ring: 0x4E9C80)],
                    letterTints: [0xFF8FA8, 0xFFB36B, 0xF2D06A, 0x6FD3AE, 0x8EB8F8], keyRing: 0x4F4A4C)),
        signature("prism-ocean", "Prism Ocean", "Outlined pill keys in blues and teals", profile: .ringed,
                  roundness: 0.6,
                  light: ThemeTones(key: 0xEDF1F4, text: 0x5E6A72, roles: [
                    .shift: RoleTone(0x2E6FC0),
                    .delete: RoleTone(0xEDF1F4, label: 0x2E6FC0, ring: 0x7FA7D6),
                    .numbers: RoleTone(0xEDF1F4, label: 0x2A8A82, ring: 0x7DCBC4),
                    .ret: RoleTone(0xEDF1F4, label: 0x4A5EB8, ring: 0x8FA0E0)],
                    letterTints: [0x3E8FC2, 0x2FA8A0, 0x5E78D0, 0x7A68C8, 0x3FB6D2], keyRing: 0xC3CDD4),
                  dark: ThemeTones(key: 0x2C3238, text: 0xC9D3DA, roles: [
                    .shift: RoleTone(0x3D80D4),
                    .delete: RoleTone(0x2C3238, label: 0x6FB5E6, ring: 0x4E7AAE),
                    .numbers: RoleTone(0x2C3238, label: 0x5FCFC6, ring: 0x3F8F88),
                    .ret: RoleTone(0x2C3238, label: 0x8EA2EE, ring: 0x5A68A8)],
                    letterTints: [0x6FB5E6, 0x5FCFC6, 0x8EA2EE, 0xA596EA, 0x6FD3EA], keyRing: 0x465058)),
    ]

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
