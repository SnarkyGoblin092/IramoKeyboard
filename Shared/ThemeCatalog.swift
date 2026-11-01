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

    /// Relative brightness (0 black ... 1 white), for picking readable text.
    var luminance: Double { return 0.2126 * r + 0.7152 * g + 0.0722 * b }

    func withAlpha(_ alpha: Double) -> ThemeRGBA { return ThemeRGBA(r, g, b, min(max(alpha, 0), 1)) }

    /// Mixed toward white (amount > 0) or black (amount < 0); alpha is kept.
    func shaded(_ amount: Double) -> ThemeRGBA {
        let target: Double = amount >= 0 ? 1 : 0
        let t = min(abs(amount), 1)
        return ThemeRGBA(r + (target - r) * t, g + (target - g) * t, b + (target - b) * t, a)
    }

    /// `other` laid over this colour with `amount` of its strength (0: this colour, 1: `other`); opaque.
    func mixed(with other: ThemeRGBA, _ amount: Double) -> ThemeRGBA {
        let t = min(max(amount, 0), 1)
        return ThemeRGBA(r + (other.r - r) * t, g + (other.g - g) * t, b + (other.b - b) * t, 1)
    }
}

// MARK: - Designed theme style

/// Everything that makes a designed theme look the way it does, and everything its editor changes: the colours,
/// the keys' shape and surface, and the effects (shadow or glow, glowing labels, frosted keys, a texture on the
/// backdrop). The keyboard (Keyboard/Theme.swift, KeyView, ThemeBackdropView) and the app's previews
/// (App/ThemePreview.swift, ThemeLook) both draw from it, through the derived values below, so they match.
struct ThemeStyle: Hashable, Codable {

    enum Shadow: String, Codable, CaseIterable {
        /// Flat on the backdrop.
        case none
        /// A soft drop shadow, as if the keys float a little.
        case soft
        /// A hard edge under each key in a deeper shade of it, like a keycap's side.
        case lift
        /// A hard shadow offset down and to the right in the line colour (the "brutalist" look).
        case block
        /// A halo around each key in the accent colour.
        case glow
    }

    enum Texture: String, Codable, CaseIterable {
        case none, dots, grid, lines, scanlines
    }

    /// The backdrop: a vertical gradient from `background` (top) to `backgroundEnd` (bottom); the same colour twice
    /// is a plain backdrop.
    var background: ThemeRGBA
    var backgroundEnd: ThemeRGBA
    /// Letter keys and function keys (shift, delete, 123...).
    var key: ThemeRGBA
    var function: ThemeRGBA
    /// Labels on the keys and the suggestion bar's words.
    var text: ThemeRGBA
    /// The return key, active shift, the suggestion pill, the swipe trail; the glow's colour.
    var accent: ThemeRGBA
    /// Key outlines, the backdrop's texture and the block shadow.
    var line: ThemeRGBA

    /// Corner roundness: a share of half the key's shorter side (0 square ... 1 capsule), as the Keys screen's.
    var roundness: Double
    /// How solid the keys are (0 clear, only their outline and effects ... 1 opaque).
    var keyOpacity: Double
    /// A blur of the backdrop behind each key (frosted glass); shows with a key opacity under 1.
    var frosted: Bool
    /// The key darkens toward its bottom edge (0 flat ... 1 deep).
    var depth: Double
    /// Light across the top of the key (0 none ... 1 glossy).
    var sheen: Double
    /// Outline width in points (0 none).
    var borderWidth: Double
    var shadow: Shadow
    var shadowStrength: Double
    /// A glow around the labels in their own colour (0 none ... 1 neon).
    var textGlow: Double
    var texture: Texture
    var textureStrength: Double
}

extension ThemeStyle {
    /// The editor's ranges.
    static let borderWidthRange: ClosedRange<Double> = 0...3

    /// Dark themes force the keyboard (and the system's own parts, such as the globe menu) into dark mode.
    var isDark: Bool { return background.mixed(with: backgroundEnd, 0.5).luminance < 0.5 }

    /// Near-black on light accents, white on dark ones.
    var onAccent: ThemeRGBA {
        return accent.luminance > 0.6 ? ThemeRGBA(0.07, 0.07, 0.08, 1) : ThemeRGBA(1, 1, 1, 1)
    }

    var secondaryText: ThemeRGBA { return text.withAlpha(text.a * 0.6) }

    var keyFill: ThemeRGBA { return key.withAlpha(key.a * keyOpacity) }
    var functionFill: ThemeRGBA { return function.withAlpha(function.a * keyOpacity) }

    /// A pressed key: lighter on dark keys, darker on light ones, and at least partly solid so a clear key shows it.
    private func pressed(_ c: ThemeRGBA) -> ThemeRGBA {
        return c.shaded(c.luminance > 0.5 ? -0.16 : 0.22).withAlpha(max(c.a * keyOpacity, 0.6))
    }
    var keyPressedFill: ThemeRGBA { return pressed(key) }
    var functionPressedFill: ThemeRGBA { return pressed(function) }

    /// Popups (the key balloon, the accent strip) are solid: the key as it shows over the backdrop.
    var popupFill: ThemeRGBA { return background.mixed(with: key, max(keyOpacity, 0.85)) }

    /// The sheen and depth gradient over a key, top to bottom at 0, 0.55 and 1 (white, clear, black alphas).
    var sheenAlphas: (top: Double, bottom: Double) { return (sheen * 0.55, depth * 0.45) }
    var hasSheen: Bool { return sheen > 0.001 || depth > 0.001 }

    /// The key's shadow in keyboard points (scaled by the previews), or nil for none.
    struct ShadowMetrics {
        let color: ThemeRGBA
        let opacity: Double
        let radius: Double
        let x: Double
        let y: Double
    }

    func shadowMetrics(pressed: Bool) -> ShadowMetrics? {
        let s = min(max(shadowStrength, 0), 1)
        guard s > 0.001 else { return nil }
        switch shadow {
        case .none:
            return nil
        case .soft:
            return ShadowMetrics(color: ThemeRGBA(0, 0, 0, 1), opacity: (0.12 + 0.38 * s) * (pressed ? 0.5 : 1),
                                 radius: pressed ? 1 : 1 + 4 * s, x: 0, y: pressed ? 0.5 : 1 + 2.5 * s)
        case .lift:
            return ShadowMetrics(color: key.shaded(-0.45).withAlpha(1), opacity: 1,
                                 radius: 0, x: 0, y: pressed ? 0.5 : 1 + 4 * s)
        case .block:
            let offset = pressed ? 0.5 : 1 + 4 * s
            return ShadowMetrics(color: line.withAlpha(1), opacity: 1, radius: 0, x: offset, y: offset)
        case .glow:
            return ShadowMetrics(color: accent.withAlpha(1), opacity: (0.35 + 0.65 * s) * (pressed ? 0.6 : 1),
                                 radius: 3 + 10 * s, x: 0, y: 0)
        }
    }

    /// The labels' glow in keyboard points, or nil for none.
    var labelGlow: (radius: Double, opacity: Double)? {
        guard textGlow > 0.001 else { return nil }
        return (2 + 6 * textGlow, 0.35 + 0.65 * textGlow)
    }

    /// The backdrop's texture, in keyboard points: the pattern's pitch, the mark's size and its colour.
    var textureMetrics: (spacing: Double, size: Double, color: ThemeRGBA)? {
        guard texture != .none, textureStrength > 0.001 else { return nil }
        let color = line.withAlpha(line.a * textureStrength * 0.45)
        switch texture {
        case .none: return nil
        case .dots: return (12, 1.2, color)
        case .grid: return (22, 0.6, color)
        case .lines: return (16, 0.7, color)
        case .scanlines: return (3, 1, color)
        }
    }
}

// MARK: - Theme definition

/// One keyboard theme. The keyboard (Keyboard/Theme.swift) and the app's theme picker both read this,
/// so previews always match the real thing.
struct ThemeDefinition: Hashable {

    enum Kind: String {
        /// Follows the system: native iOS keys on the system keyboard backdrop.
        case native
        /// See-through keys over the clear keyboard backdrop (the wallpaper/app shows through).
        case transparent
        /// iOS 26 Liquid Glass keys/popups/strip (real `UIGlassEffect`); older iOS falls back to a blur.
        case liquidGlass
        /// A theme of its own, drawn from `style` on its own backdrop; the theme editor changes it.
        case designed
    }

    /// Stored in `Settings.theme`. Never change an id once shipped.
    let id: String
    /// Name shown in the picker.
    let name: String
    let kind: Kind
    /// What makes it different, in a few words (the editor's subtitle).
    let summary: String
    /// The look of a designed theme, with the user's edits (nil for the system themes).
    var style: ThemeStyle? = nil
    /// True when the user changed this theme in the editor.
    var isEdited = false

    /// nil = follow the system light/dark setting. true/false forces the keyboard into dark/light.
    var isDark: Bool? { return style?.isDark }
}

// MARK: - Edits

/// The theme editor's changes: every edited designed theme's whole style, by theme id, as JSON in one string
/// (`SettingKey.themeEdits` in the App Group defaults, read by the keyboard when it rebuilds). A theme without an
/// entry looks as designed; resetting it removes the entry.
enum ThemeEdits {
    private static var cache: (text: String, edits: [String: ThemeStyle]) = ("", [:])

    static func decode(_ text: String) -> [String: ThemeStyle] {
        if text == cache.text { return cache.edits }
        let edits = text.data(using: .utf8).flatMap { try? JSONDecoder().decode([String: ThemeStyle].self, from: $0) } ?? [:]
        cache = (text, edits)
        return edits
    }

    static func encode(_ edits: [String: ThemeStyle]) -> String {
        guard !edits.isEmpty else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(edits) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// `text` with `style` saved for the theme `id`: removed when it is nil or the theme's own design.
    static func setting(_ style: ThemeStyle?, for id: String, in text: String) -> String {
        var edits = decode(text)
        if let style = style, style != ThemeCatalog.base(id: id).style {
            edits[id] = style
        } else {
            edits[id] = nil
        }
        return encode(edits)
    }
}

// MARK: - Catalog

enum ThemeCatalog {

    static let defaultID = "native"

    /// The themes that follow the system's own look.
    static let system: [ThemeDefinition] = [native, transparent, liquidGlass]
    /// One of each designed look, in picker order.
    static let designed: [ThemeDefinition] = [synthwave, terminal, keycap, frost, candy, paper, brutalist, gilded, ember, clay]
    static let all: [ThemeDefinition] = system + designed

    /// The theme as designed, without the user's edits. Unknown ids (including the removed key-colour themes)
    /// fall back to Native.
    static func base(id: String) -> ThemeDefinition {
        for theme in all where theme.id == id { return theme }
        return native
    }

    /// The theme with the editor's changes in `edits` (the stored `SettingKey.themeEdits`).
    static func theme(id: String, edits: String) -> ThemeDefinition {
        var theme = base(id: id)
        if theme.style != nil, let style = ThemeEdits.decode(edits)[theme.id] {
            theme.style = style
            theme.isEdited = true
        }
        return theme
    }

    /// The theme with the stored edits.
    static func theme(id: String) -> ThemeDefinition {
        return theme(id: id, edits: SharedStore.defaults.string(forKey: SettingKey.themeEdits) ?? "")
    }

    // MARK: System themes

    /// Follows the system exactly (native iOS look).
    static let native = ThemeDefinition(id: "native", name: "Native", kind: .native,
                                        summary: "The iOS keyboard, in light and dark mode")

    /// See-through keys over the clear backdrop.
    static let transparent = ThemeDefinition(id: "transparent", name: "Transparent", kind: .transparent,
                                             summary: "See-through keys over a frosted panel")

    /// iOS 26 Liquid Glass. Glass keys float over a clear backdrop.
    static let liquidGlass = ThemeDefinition(id: "liquidglass", name: "Liquid Glass", kind: .liquidGlass,
                                             summary: "Real Liquid Glass keys over the app")

    // MARK: Designed themes

    private static func make(_ id: String, _ name: String, _ summary: String, _ style: ThemeStyle) -> ThemeDefinition {
        return ThemeDefinition(id: id, name: name, kind: .designed, summary: summary, style: style)
    }

    private static func c(_ hex: UInt32, _ alpha: Double = 1) -> ThemeRGBA { return ThemeRGBA(hex: hex, alpha: alpha) }

    static let synthwave = make("synthwave", "Synthwave", "Neon grid, glowing keys and labels", ThemeStyle(
        background: c(0x2B1055), backgroundEnd: c(0x0D0221),
        key: c(0x1A0B33), function: c(0x2A0F4F), text: c(0xFFE6FF), accent: c(0xFF2E97), line: c(0xFF2E97),
        roundness: 0.22, keyOpacity: 0.82, frosted: false, depth: 0, sheen: 0.15, borderWidth: 1,
        shadow: .glow, shadowStrength: 0.55, textGlow: 0.7, texture: .grid, textureStrength: 0.5))

    static let terminal = make("terminal", "Terminal", "Green phosphor, scanlines and square keys", ThemeStyle(
        background: c(0x030803), backgroundEnd: c(0x071207),
        key: c(0x081208), function: c(0x0C1C0C), text: c(0x33FF66), accent: c(0x33FF66), line: c(0x33FF66, 0.55),
        roundness: 0, keyOpacity: 1, frosted: false, depth: 0, sheen: 0, borderWidth: 0.8,
        shadow: .none, shadowStrength: 0, textGlow: 0.55, texture: .scanlines, textureStrength: 0.6))

    static let keycap = make("keycap", "Keycap", "Chunky mechanical caps with a deep edge", ThemeStyle(
        background: c(0xCFC8B8), backgroundEnd: c(0xB9B09C),
        key: c(0xF5F0E4), function: c(0xA9A08E), text: c(0x2B2722), accent: c(0xE2553D), line: c(0x8E8573),
        roundness: 0.16, keyOpacity: 1, frosted: false, depth: 0.35, sheen: 0.25, borderWidth: 0.5,
        shadow: .lift, shadowStrength: 0.8, textGlow: 0, texture: .none, textureStrength: 0))

    static let frost = make("frost", "Frost", "Frosted glass keys over a soft gradient", ThemeStyle(
        background: c(0x8EC5FC), backgroundEnd: c(0xE0C3FC),
        key: c(0xFFFFFF), function: c(0xDCE6FF), text: c(0x1B2440), accent: c(0x5B6CFF), line: c(0xFFFFFF, 0.9),
        roundness: 0.4, keyOpacity: 0.35, frosted: true, depth: 0, sheen: 0.5, borderWidth: 0.8,
        shadow: .none, shadowStrength: 0, textGlow: 0, texture: .none, textureStrength: 0))

    static let candy = make("candy", "Candy", "Glossy pill keys on dotted pink", ThemeStyle(
        background: c(0xFFD6EA), backgroundEnd: c(0xFFC2DF),
        key: c(0xFF7AB6), function: c(0x7CC8FF), text: c(0xFFFFFF), accent: c(0x7C4DFF), line: c(0xFFFFFF, 0.9),
        roundness: 1, keyOpacity: 1, frosted: false, depth: 0.3, sheen: 0.8, borderWidth: 0,
        shadow: .soft, shadowStrength: 0.5, textGlow: 0, texture: .dots, textureStrength: 0.6))

    static let paper = make("paper", "Paper", "Ink outlines on ruled paper", ThemeStyle(
        background: c(0xF7F2E6), backgroundEnd: c(0xF1EBDC),
        key: c(0xFFFDF7), function: c(0xEDE5D3), text: c(0x1E1C1A), accent: c(0x1E1C1A), line: c(0x2B2825),
        roundness: 0.1, keyOpacity: 0.5, frosted: false, depth: 0, sheen: 0, borderWidth: 1.1,
        shadow: .none, shadowStrength: 0, textGlow: 0, texture: .lines, textureStrength: 0.35))

    static let brutalist = make("brutalist", "Brutalist", "Thick outlines and hard offset shadows", ThemeStyle(
        background: c(0xFFD23F), backgroundEnd: c(0xFFD23F),
        key: c(0xFFFFFF), function: c(0xFF8FA3), text: c(0x111111), accent: c(0x3D5AFE), line: c(0x111111),
        roundness: 0.08, keyOpacity: 1, frosted: false, depth: 0, sheen: 0, borderWidth: 2,
        shadow: .block, shadowStrength: 0.6, textGlow: 0, texture: .none, textureStrength: 0))

    static let gilded = make("gilded", "Gilded", "Midnight keys trimmed in gold", ThemeStyle(
        background: c(0x121A2E), backgroundEnd: c(0x05070D),
        key: c(0x1A2340), function: c(0x111833), text: c(0xEED9A0), accent: c(0xD4AF37), line: c(0xD4AF37, 0.85),
        roundness: 0.3, keyOpacity: 1, frosted: false, depth: 0.3, sheen: 0.2, borderWidth: 0.8,
        shadow: .soft, shadowStrength: 0.6, textGlow: 0.15, texture: .none, textureStrength: 0))

    static let ember = make("ember", "Ember", "Dark keys glowing like coals", ThemeStyle(
        background: c(0x2A0700), backgroundEnd: c(0x0F0200),
        key: c(0x261008), function: c(0x1A0A05), text: c(0xFFC29A), accent: c(0xFF5A1F), line: c(0xFF7A3D, 0.5),
        roundness: 0.45, keyOpacity: 1, frosted: false, depth: 0.2, sheen: 0.1, borderWidth: 0.6,
        shadow: .glow, shadowStrength: 0.65, textGlow: 0.35, texture: .none, textureStrength: 0))

    static let clay = make("clay", "Clay", "Soft, puffy keys of the backdrop's own colour", ThemeStyle(
        background: c(0xE6E1DA), backgroundEnd: c(0xDCD6CD),
        key: c(0xEAE5DE), function: c(0xD8D1C6), text: c(0x5E554C), accent: c(0xE07A5F), line: c(0xFFFFFF, 0.7),
        roundness: 0.45, keyOpacity: 1, frosted: false, depth: 0.15, sheen: 0.55, borderWidth: 0.6,
        shadow: .soft, shadowStrength: 0.7, textGlow: 0, texture: .none, textureStrength: 0))
}
