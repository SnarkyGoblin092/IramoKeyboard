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

    init(from decoder: Swift.Decoder) throws {
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

/// What one effect looks like on its own: its colour, the way it goes and where on the key it starts. "inherit" takes
/// the setting for all the effects.
struct EffectStyle: Hashable, Codable {
    var colorMode = "inherit"
    var customColor = ThemeRGBA(hex: 0x00E5FF)
    var direction = "inherit"
    var position = "inherit"
}

/// Everything the Effects screen changes: effects played on a key as it is pressed, each with its own settings.
struct EffectsConfig: Hashable, Codable {
    /// "accent", "white", "rainbow" (a new hue each press) or "custom".
    var colorMode = "accent"
    var customColor = ThemeRGBA(hex: 0x00E5FF)
    /// Which way the effects go: "auto" (each as designed), "up", "down", "left", "right" or "random" (a new way
    /// for each press).
    var direction = "auto"
    /// Where on the key the effects start: "auto" (the middle), "top", "bottom", "left", "right" or "random".
    var position = "auto"
    /// The effects that have a colour, direction or position of their own, by effect id (the flag's name, or the
    /// catalog's id).
    var styles: [String: EffectStyle] = [:]

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

    /// A ring of light that spreads out far past the key.
    var shockwave = false
    var shockReach = 1.8
    var shockDuration = 0.6

    /// Small pieces of paper thrown up out of the key that tumble down.
    var confetti = false
    var confettiCount = 14.0
    var confettiDuration = 0.9

    /// Bubbles that float up from the key.
    var bubbles = false
    var bubbleCount = 5.0
    var bubbleRise = 60.0

    /// The key squashes under the finger and springs back.
    var squish = false
    var squishDepth = 0.85

    /// The key flashes in the effect colour.
    var flash = false
    var flashStrength = 0.6
    var flashDuration = 0.3

    /// The key wobbles like jelly.
    var jelly = false
    var jellyAngle = 8.0

    /// Little hearts float up from the key.
    var hearts = false
    var heartCount = 6.0

    /// Stars burst out of the key and fade.
    var stars = false
    var starCount = 7.0

    /// Snowflakes drift down past the key.
    var snow = false
    var snowCount = 10.0

    /// Musical notes drift up and to the side.
    var notes = false
    var noteCount = 4.0

    /// Streaks burst out of the key and fall like fireworks.
    var fireworks = false
    var fireworkCount = 16.0

    /// Thin rays shoot out of the key in every direction.
    var starburst = false
    var rayCount = 12.0

    /// Drops of rain fall past the key.
    var rain = false
    var rainCount = 9.0

    /// Glowing embers rise and flicker out.
    var embers = false
    var emberCount = 9.0

    /// Soft puffs of smoke rise from the key and grow.
    var smoke = false
    var smokeCount = 4.0

    /// A bolt of lightning strikes up from the key.
    var lightning = false
    var lightningLength = 2.0

    /// Little lights circle around the key.
    var orbit = false
    var orbitCount = 4.0

    /// Specks spiral outwards from the key.
    var spiral = false
    var spiralCount = 12.0

    /// The key pulses twice like a heartbeat.
    var heartbeat = false
    var heartbeatStrength = 1.15

    /// The key flips over like a card.
    var flip = false
    var flipDuration = 0.45

    /// The key shakes from side to side.
    var shake = false
    var shakeDistance = 6.0

    /// The key sinks and bounces back.
    var drop = false
    var dropDepth = 8.0

    /// The key glitches with flickering colours.
    var glitch = false
    var glitchStrength = 0.6

    /// A line grows along the bottom of the key and fades.
    var underline = false
    var underlineDuration = 0.4

    /// A light runs round the key's outline.
    var sweep = false
    var sweepDuration = 0.5

    /// The effects of the catalog (EffectCatalog) that are on, and the settings the user changed (by "id.setting").
    var moreOn: [String] = []
    var moreValues: [String: Double] = [:]

    /// The swipe trail glows in the effect colour.
    var trail = false
    var trailGlow = 0.8

    init() {}

    init(from decoder: Swift.Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        colorMode = value(c, .colorMode, colorMode)
        direction = value(c, .direction, direction)
        position = value(c, .position, position)
        styles = value(c, .styles, styles)
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
        shockwave = value(c, .shockwave, shockwave)
        shockReach = value(c, .shockReach, shockReach)
        shockDuration = value(c, .shockDuration, shockDuration)
        confetti = value(c, .confetti, confetti)
        confettiCount = value(c, .confettiCount, confettiCount)
        confettiDuration = value(c, .confettiDuration, confettiDuration)
        bubbles = value(c, .bubbles, bubbles)
        bubbleCount = value(c, .bubbleCount, bubbleCount)
        bubbleRise = value(c, .bubbleRise, bubbleRise)
        squish = value(c, .squish, squish)
        squishDepth = value(c, .squishDepth, squishDepth)
        flash = value(c, .flash, flash)
        flashStrength = value(c, .flashStrength, flashStrength)
        flashDuration = value(c, .flashDuration, flashDuration)
        jelly = value(c, .jelly, jelly)
        jellyAngle = value(c, .jellyAngle, jellyAngle)
        hearts = value(c, .hearts, hearts)
        heartCount = value(c, .heartCount, heartCount)
        stars = value(c, .stars, stars)
        starCount = value(c, .starCount, starCount)
        snow = value(c, .snow, snow)
        snowCount = value(c, .snowCount, snowCount)
        notes = value(c, .notes, notes)
        noteCount = value(c, .noteCount, noteCount)
        fireworks = value(c, .fireworks, fireworks)
        fireworkCount = value(c, .fireworkCount, fireworkCount)
        starburst = value(c, .starburst, starburst)
        rayCount = value(c, .rayCount, rayCount)
        rain = value(c, .rain, rain)
        rainCount = value(c, .rainCount, rainCount)
        embers = value(c, .embers, embers)
        emberCount = value(c, .emberCount, emberCount)
        smoke = value(c, .smoke, smoke)
        smokeCount = value(c, .smokeCount, smokeCount)
        lightning = value(c, .lightning, lightning)
        lightningLength = value(c, .lightningLength, lightningLength)
        orbit = value(c, .orbit, orbit)
        orbitCount = value(c, .orbitCount, orbitCount)
        spiral = value(c, .spiral, spiral)
        spiralCount = value(c, .spiralCount, spiralCount)
        heartbeat = value(c, .heartbeat, heartbeat)
        heartbeatStrength = value(c, .heartbeatStrength, heartbeatStrength)
        flip = value(c, .flip, flip)
        flipDuration = value(c, .flipDuration, flipDuration)
        shake = value(c, .shake, shake)
        shakeDistance = value(c, .shakeDistance, shakeDistance)
        drop = value(c, .drop, drop)
        dropDepth = value(c, .dropDepth, dropDepth)
        glitch = value(c, .glitch, glitch)
        glitchStrength = value(c, .glitchStrength, glitchStrength)
        underline = value(c, .underline, underline)
        underlineDuration = value(c, .underlineDuration, underlineDuration)
        sweep = value(c, .sweep, sweep)
        sweepDuration = value(c, .sweepDuration, sweepDuration)
        moreOn = value(c, .moreOn, moreOn).filter { EffectCatalog.entry($0) != nil }   // drops effects since removed
        moreValues = value(c, .moreValues, moreValues)
        trail = value(c, .trail, trail)
        trailGlow = value(c, .trailGlow, trailGlow)
    }

    /// Whether any effect is on.
    var isOn: Bool { return playsOnPress || trail }

    /// Whether any effect plays when a key goes down (the trail is for swipes).
    var playsOnPress: Bool {
        return !moreOn.isEmpty || glow || border || ripple || shine || sparks || pop
            || echo || wave || shockwave || confetti || bubbles || squish
            || flash || jelly || hearts || stars || snow || notes
            || fireworks || starburst || rain || embers || smoke || lightning
            || orbit || spiral || heartbeat || flip || shake || drop
            || glitch || underline || sweep
    }

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
    static let shockReachRange: ClosedRange<Double> = 1...4
    static let shockDurationRange: ClosedRange<Double> = 0.2...1.5
    static let confettiCountRange: ClosedRange<Double> = 6...30
    static let confettiDurationRange: ClosedRange<Double> = 0.5...1.6
    static let bubbleCountRange: ClosedRange<Double> = 2...10
    static let bubbleRiseRange: ClosedRange<Double> = 20...140
    static let squishDepthRange: ClosedRange<Double> = 0.7...0.95
    static let flashStrengthRange: ClosedRange<Double> = 0.1...1
    static let flashDurationRange: ClosedRange<Double> = 0.1...0.8
    static let jellyAngleRange: ClosedRange<Double> = 3...20
    static let heartCountRange: ClosedRange<Double> = 3.0...12.0
    static let starCountRange: ClosedRange<Double> = 3.0...14.0
    static let snowCountRange: ClosedRange<Double> = 4.0...20.0
    static let noteCountRange: ClosedRange<Double> = 2.0...8.0
    static let fireworkCountRange: ClosedRange<Double> = 8.0...30.0
    static let rayCountRange: ClosedRange<Double> = 6.0...24.0
    static let rainCountRange: ClosedRange<Double> = 4.0...20.0
    static let emberCountRange: ClosedRange<Double> = 4.0...20.0
    static let smokeCountRange: ClosedRange<Double> = 2.0...8.0
    static let lightningLengthRange: ClosedRange<Double> = 1.0...4.0
    static let orbitCountRange: ClosedRange<Double> = 2.0...8.0
    static let spiralCountRange: ClosedRange<Double> = 6.0...24.0
    static let heartbeatStrengthRange: ClosedRange<Double> = 1.05...1.4
    static let flipDurationRange: ClosedRange<Double> = 0.2...1.0
    static let shakeDistanceRange: ClosedRange<Double> = 2.0...14.0
    static let dropDepthRange: ClosedRange<Double> = 2.0...16.0
    static let glitchStrengthRange: ClosedRange<Double> = 0.2...1.0
    static let underlineDurationRange: ClosedRange<Double> = 0.15...1.0
    static let sweepDurationRange: ClosedRange<Double> = 0.2...1.2
    static let trailGlowRange: ClosedRange<Double> = 0.2...1

    // MARK: Each effect's own look

    func style(_ id: String) -> EffectStyle { return styles[id] ?? EffectStyle() }

    mutating func editStyle(_ id: String, _ edit: (inout EffectStyle) -> Void) {
        var next = style(id)
        edit(&next)
        if next == EffectStyle() { styles.removeValue(forKey: id) } else { styles[id] = next }
    }

    /// The colour mode of an effect: its own, else the one for all.
    func mode(for id: String) -> String {
        let own = style(id).colorMode
        return own == "inherit" ? colorMode : own
    }

    func custom(for id: String) -> ThemeRGBA {
        return style(id).colorMode == "custom" ? style(id).customColor : customColor
    }

    func direction(for id: String) -> String {
        let own = style(id).direction
        return own == "inherit" ? direction : own
    }

    func position(for id: String) -> String {
        let own = style(id).position
        return own == "inherit" ? position : own
    }

    // MARK: The catalog's effects

    /// How many effects are on: the built-in ones and the catalog's.
    var activeCount: Int {
        let flags = [glow, border, ripple, shine, sparks, pop, echo, wave, shockwave, confetti, bubbles, squish,
                     flash, jelly, hearts, stars, snow, notes, fireworks, starburst, rain, embers, smoke, lightning,
                     orbit, spiral, heartbeat, flip, shake, drop, glitch, underline, sweep, trail]
        let known = Set(EffectCatalog.all.map { $0.id })
        return flags.filter { $0 }.count + Set(moreOn).filter { known.contains($0) }.count
    }

    func isOn(_ id: String) -> Bool { return moreOn.contains(id) }

    mutating func setOn(_ id: String, _ on: Bool) {
        moreOn.removeAll { $0 == id }
        if on { moreOn.append(id) }
        moreOn.sort()
    }

    /// A setting of a catalog effect: what the user set, else its default.
    func setting(_ entry: EffectEntry, _ name: String) -> Double {
        if let stored = moreValues[entry.id + "." + name] { return stored }
        return entry.params.first { $0.id == name }?.value ?? 1
    }

    mutating func set(_ entry: EffectEntry, _ name: String, _ number: Double) {
        let key = entry.id + "." + name
        if let param = entry.params.first(where: { $0.id == name }), abs(param.value - number) < 0.0001 {
            moreValues.removeValue(forKey: key)
        } else {
            moreValues[key] = number
        }
    }

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
