import Foundation
import CoreGraphics

// Two small models the app edits and the keyboard reads, each stored as one JSON string in the App Group defaults:
// the look of a system theme (SystemStyle) and the effects on pressed keys (EffectsConfig). A value missing from
// stored JSON (an older version, or one added later) takes its default.

/// Decodes `key` when it is there, else `fallback`.
private func value<T: Decodable, K: CodingKey>(_ container: KeyedDecodingContainer<K>, _ key: K, _ fallback: T) -> T {
    return ((try? container.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
}

// MARK: - System themes

/// What a system theme's editor changes: the corners and key style (which were global settings before the three
/// themes each had an editor), and colours, solidity, outline and glow. A theme without one looks as it always did,
/// with the old global settings.
struct SystemStyle: Hashable, Codable {
    /// 0 square ... 1 capsule (a share of half the key's shorter side).
    var roundness = 0.26
    /// "auto", "flat", "sheen" or "raised".
    var surface = "auto"
    /// "auto", "none", "thin", "bold" or "accent".
    var border = "auto"
    /// An outline width in points that replaces the border's own (nil: the border's).
    var borderWidth: Double? = nil
    /// "off", "soft" or "strong": an accent glow around the keys.
    var glow = "off"
    /// How solid the keys are (0.2 nearly clear ... 1 as the theme draws them).
    var keyOpacity = 1.0
    /// How strong the sheen and shade on a sheen or raised key are (0 ... 2; 1 as drawn).
    var sheen = 1.0
    /// A glow around the labels in their own colour (0 none ... 1 neon).
    var labelGlow = 0.0
    /// Colours that replace the theme's own (nil: its own).
    var letterColor: ThemeRGBA? = nil
    var functionColor: ThemeRGBA? = nil
    var labelColor: ThemeRGBA? = nil

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        roundness = value(c, .roundness, roundness)
        surface = value(c, .surface, surface)
        border = value(c, .border, border)
        borderWidth = value(c, .borderWidth, borderWidth)
        glow = value(c, .glow, glow)
        keyOpacity = value(c, .keyOpacity, keyOpacity)
        sheen = value(c, .sheen, sheen)
        labelGlow = value(c, .labelGlow, labelGlow)
        letterColor = value(c, .letterColor, letterColor)
        functionColor = value(c, .functionColor, functionColor)
        labelColor = value(c, .labelColor, labelColor)
    }

    static let roundnessRange: ClosedRange<Double> = 0...1
    static let borderWidthRange: ClosedRange<Double> = 0...3
    static let keyOpacityRange: ClosedRange<Double> = 0.2...1
    static let sheenRange: ClosedRange<Double> = 0...2
}

/// The system themes' edits by theme id, as JSON in `SettingKey.systemEdits`.
enum SystemEdits {
    private static var cache: (text: String, edits: [String: SystemStyle]) = ("", [:])

    static func decode(_ text: String) -> [String: SystemStyle] {
        if text == cache.text { return cache.edits }
        let edits = text.data(using: .utf8).flatMap { try? JSONDecoder().decode([String: SystemStyle].self, from: $0) } ?? [:]
        cache = (text, edits)
        return edits
    }

    static func encode(_ edits: [String: SystemStyle]) -> String {
        guard !edits.isEmpty else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(edits) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// `text` with `style` saved for the theme `id` (removed when nil).
    static func setting(_ style: SystemStyle?, for id: String, in text: String) -> String {
        var edits = decode(text)
        edits[id] = style
        return encode(edits)
    }
}

// MARK: - Effects

/// Everything the Effects screen changes: effects played on a key as it is pressed, each with its own settings.
struct EffectsConfig: Hashable, Codable {
    /// "accent", "white", "rainbow" (a new hue each press) or "custom".
    var colorMode = "accent"
    var customColor = ThemeRGBA(hex: 0x00E5FF)

    /// A light around the key that fades in under the finger and out after it lifts.
    var glow = false
    var glowStrength = 0.6
    var glowSpread = 1.0
    var glowFadeIn = 0.06
    var glowFadeOut = 0.4

    /// A thin line round the key that lights up.
    var border = false
    var borderWidth = 1.5
    var borderFade = 0.5

    /// A disc or ring of light spreading from the middle of the key.
    var ripple = false
    var rippleStyle = "disc"
    var rippleReach = 1.8
    var rippleDuration = 0.6

    /// A band of light sweeping across the key.
    var shine = false
    var shineDuration = 0.45
    var shineWidth = 0.5

    /// Specks that fly out of the key.
    var sparks = false
    var sparkCount = 8.0
    var sparkDistance = 1.0
    var sparkSize = 3.0
    var sparkDuration = 0.6

    /// The label swells (or shrinks) and springs back.
    var pop = false
    var popScale = 1.35
    var popDuration = 0.3

    /// A copy of the label floats up and fades.
    var echo = false
    var echoRise = 24.0
    var echoDuration = 0.55

    /// The keys around the pressed one light up in turn, farther ones later.
    var wave = false
    var waveReach = 1.8
    var waveStrength = 0.5
    var waveSpeed = 0.07

    /// The swipe trail glows in the effect colour.
    var trail = false
    var trailGlow = 0.8

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        colorMode = value(c, .colorMode, colorMode)
        customColor = value(c, .customColor, customColor)
        glow = value(c, .glow, glow)
        glowStrength = value(c, .glowStrength, glowStrength)
        glowSpread = value(c, .glowSpread, glowSpread)
        glowFadeIn = value(c, .glowFadeIn, glowFadeIn)
        glowFadeOut = value(c, .glowFadeOut, glowFadeOut)
        border = value(c, .border, border)
        borderWidth = value(c, .borderWidth, borderWidth)
        borderFade = value(c, .borderFade, borderFade)
        ripple = value(c, .ripple, ripple)
        rippleStyle = value(c, .rippleStyle, rippleStyle)
        rippleReach = value(c, .rippleReach, rippleReach)
        rippleDuration = value(c, .rippleDuration, rippleDuration)
        shine = value(c, .shine, shine)
        shineDuration = value(c, .shineDuration, shineDuration)
        shineWidth = value(c, .shineWidth, shineWidth)
        sparks = value(c, .sparks, sparks)
        sparkCount = value(c, .sparkCount, sparkCount)
        sparkDistance = value(c, .sparkDistance, sparkDistance)
        sparkSize = value(c, .sparkSize, sparkSize)
        sparkDuration = value(c, .sparkDuration, sparkDuration)
        pop = value(c, .pop, pop)
        popScale = value(c, .popScale, popScale)
        popDuration = value(c, .popDuration, popDuration)
        echo = value(c, .echo, echo)
        echoRise = value(c, .echoRise, echoRise)
        echoDuration = value(c, .echoDuration, echoDuration)
        wave = value(c, .wave, wave)
        waveReach = value(c, .waveReach, waveReach)
        waveStrength = value(c, .waveStrength, waveStrength)
        waveSpeed = value(c, .waveSpeed, waveSpeed)
        trail = value(c, .trail, trail)
        trailGlow = value(c, .trailGlow, trailGlow)
    }

    /// Whether any effect is on.
    var isOn: Bool { return glow || border || ripple || shine || sparks || pop || echo || wave || trail }

    /// Whether any effect plays when a key goes down (the trail is for swipes).
    var playsOnPress: Bool { return glow || border || ripple || shine || sparks || pop || echo || wave }

    static let glowStrengthRange: ClosedRange<Double> = 0.1...1
    static let glowSpreadRange: ClosedRange<Double> = 0.5...2.5
    static let glowFadeInRange: ClosedRange<Double> = 0...0.5
    static let glowFadeOutRange: ClosedRange<Double> = 0.05...1.5
    static let borderWidthRange: ClosedRange<Double> = 0.5...4
    static let borderFadeRange: ClosedRange<Double> = 0.1...1.5
    static let rippleReachRange: ClosedRange<Double> = 1.2...3
    static let rippleDurationRange: ClosedRange<Double> = 0.2...1.5
    static let shineDurationRange: ClosedRange<Double> = 0.2...1
    static let shineWidthRange: ClosedRange<Double> = 0.2...1
    static let sparkCountRange: ClosedRange<Double> = 3...16
    static let sparkDistanceRange: ClosedRange<Double> = 0.5...2.5
    static let sparkSizeRange: ClosedRange<Double> = 1.5...6
    static let sparkDurationRange: ClosedRange<Double> = 0.25...1.2
    static let popScaleRange: ClosedRange<Double> = 0.6...1.8
    static let popDurationRange: ClosedRange<Double> = 0.1...0.8
    static let echoRiseRange: ClosedRange<Double> = 8...60
    static let echoDurationRange: ClosedRange<Double> = 0.2...1.2
    static let waveReachRange: ClosedRange<Double> = 1...3.5
    static let waveStrengthRange: ClosedRange<Double> = 0.1...1
    static let waveSpeedRange: ClosedRange<Double> = 0.02...0.2
    static let trailGlowRange: ClosedRange<Double> = 0.2...1

    // MARK: Storage

    private static var cache: (text: String, config: EffectsConfig) = ("", EffectsConfig())

    static func decode(_ text: String) -> EffectsConfig {
        if text.isEmpty { return EffectsConfig() }
        if text == cache.text { return cache.config }
        let config = text.data(using: .utf8).flatMap { try? JSONDecoder().decode(EffectsConfig.self, from: $0) } ?? EffectsConfig()
        cache = (text, config)
        return config
    }

    /// The JSON to store (empty for the defaults: everything off).
    func encoded() -> String {
        guard self != EffectsConfig() else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(self) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
