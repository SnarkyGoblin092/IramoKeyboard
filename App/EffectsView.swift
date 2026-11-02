import SwiftUI

/// Effects on the keys while they are pressed: a glow, a lit outline, a ripple, a shine, sparks, a pop of the label,
/// an echo of it and a wave over the neighbouring keys, each with its own settings, and a glow on the swipe trail.
/// The keyboard above is touchable; the keyboard reads the same settings (Prefs.effects, KeyView).
struct EffectsView: View {
    @AppStorage(SettingKey.effects, store: SharedStore.defaults) private var json = SettingDefault.effects

    private let colorModes = EffectPalette.modes

    private var config: EffectsConfig { return EffectsConfig.decode(json) }

    private func bind<Value>(_ keyPath: WritableKeyPath<EffectsConfig, Value>) -> Binding<Value> {
        return Binding(get: { config[keyPath: keyPath] }, set: { value in
            var next = config
            next[keyPath: keyPath] = value
            json = next.encoded()
        })
    }

    private var positionNames: [(mode: String, name: String)] {
        return [("auto", tr("Middle")), ("top", tr("Top")), ("bottom", tr("Bottom")), ("left", tr("Left")),
                ("right", tr("Right")), ("random", tr("Random"))]
    }

    private func colorName(_ mode: String) -> String {
        switch mode {
        case "accent": return tr("Accent")
        case "white": return tr("White")
        case "rainbow": return tr("Rainbow")
        case "warm": return tr("Warm")
        case "cool": return tr("Cool")
        case "pastel": return tr("Pastel")
        case "neon": return tr("Neon")
        case "random": return tr("Random")
        case "custom": return tr("Custom")
        default: return tr("Same as all effects")
        }
    }

    // What each effect can have of its own. The others have no colour, or no way or place that would show.
    private static let plain: Set<String> = ["pop", "squish", "jelly", "heartbeat", "flip", "shake", "drop", "glitch", "echo", "trail"]
    private static let going: Set<String> = ["confetti", "bubbles", "echo", "beam", "hearts", "snow", "notes", "rain", "embers", "smoke"]
    private static let placed: Set<String> = ["ripple", "sparks", "echo", "shockwave", "confetti", "bubbles", "lightning", "beam", "hearts",
                                              "stars", "snow", "notes", "fireworks", "starburst", "rain", "embers", "smoke", "orbit", "spiral"]

    private func colorOptions(inherit: Bool) -> [(value: String, name: String)] {
        var list: [(value: String, name: String)] = inherit ? [(value: "inherit", name: colorName("inherit"))] : []
        for mode in colorModes { list.append((value: mode, name: colorName(mode))) }
        return list
    }

    private func directionOptions(inherit: Bool) -> [(value: String, name: String)] {
        var list: [(value: String, name: String)] = inherit ? [(value: "inherit", name: tr("Same as all effects"))] : []
        for item in directionNames { list.append((value: item.mode, name: item.name)) }
        return list
    }

    private func positionOptions(inherit: Bool) -> [(value: String, name: String)] {
        var list: [(value: String, name: String)] = inherit ? [(value: "inherit", name: tr("Same as all effects"))] : []
        for item in positionNames { list.append((value: item.mode, name: item.name)) }
        return list
    }

    private func editStyle(_ id: String, _ edit: @escaping (inout EffectStyle) -> Void) {
        var next = config
        next.editStyle(id, edit)
        json = next.encoded()
    }

    /// The colour, direction and position of one effect, under its switch.
    @ViewBuilder private func lookRows(_ id: String) -> some View {
        let isCatalog = EffectCatalog.entry(id) != nil
        let style = config.style(id)
        if isCatalog || !EffectsView.plain.contains(id) {
            GlassChoiceLink(title: tr("Colour"), symbol: "paintpalette",
                            options: colorOptions(inherit: true),
                            selected: style.colorMode) { mode in editStyle(id) { $0.colorMode = mode } }
            if style.colorMode == "custom" {
                ColorPicker(tr("Custom colour"), selection: Binding(get: { Color(style.customColor) }, set: { color in
                    editStyle(id) { $0.customColor = ThemeRGBA(effectColor: color) }
                }), supportsOpacity: false)
            }
        }
        if isCatalog || EffectsView.going.contains(id) {
            GlassChoiceLink(title: tr("Direction"), symbol: "arrow.up.and.down.and.arrow.left.and.right",
                            options: directionOptions(inherit: true),
                            selected: style.direction) { value in editStyle(id) { $0.direction = value } }
        }
        if isCatalog || EffectsView.placed.contains(id) {
            GlassChoiceLink(title: tr("Position"), symbol: "scope",
                            options: positionOptions(inherit: true),
                            selected: style.position) { value in editStyle(id) { $0.position = value } }
        }
    }

    private var directionNames: [(mode: String, name: String)] {
        return [("auto", tr("Auto")), ("up", tr("Up")), ("down", tr("Down")), ("left", tr("Left")),
                ("right", tr("Right")), ("random", tr("Random"))]
    }

    private var seconds: (Double) -> String { return { String(format: "%.2f s", $0) } }
    private var times: (Double) -> String { return { String(format: "%.1f\u{00D7}", $0) } }

    // MARK: Presets

    private struct Preset {
        let name: String
        let make: () -> EffectsConfig
    }

    private let presets: [Preset] = [
        Preset(name: tr("Off")) { EffectsConfig() },
        Preset(name: tr("Glow")) { var c = EffectsConfig(); c.glow = true; return c },
        Preset(name: tr("Neon")) {
            var c = EffectsConfig()
            c.glow = true; c.glowStrength = 1; c.glowSpread = 1.7; c.glowFadeIn = 0.03; c.glowFadeOut = 0.8
            c.border = true; c.borderFade = 0.8
            c.trail = true
            return c
        },
        Preset(name: tr("Ripple")) {
            var c = EffectsConfig()
            c.ripple = true; c.rippleReach = 2.6; c.rippleDuration = 0.7
            return c
        },
        Preset(name: tr("Rainbow")) {
            var c = EffectsConfig()
            c.colorMode = "rainbow"
            c.glow = true; c.glowStrength = 0.8; c.glowSpread = 1.3
            c.ripple = true; c.rippleStyle = "ring"
            c.trail = true
            return c
        },
        Preset(name: tr("Sparkle")) {
            var c = EffectsConfig()
            c.position = "random"
            c.colorMode = "white"
            c.sparks = true; c.sparkCount = 10
            c.shine = true
            return c
        },
        Preset(name: tr("Wave")) {
            var c = EffectsConfig()
            c.wave = true; c.waveReach = 2.4
            c.glow = true; c.glowStrength = 0.5
            return c
        },
        Preset(name: tr("Confetti")) {
            var c = EffectsConfig()
            c.direction = "random"
            c.colorMode = "rainbow"
            c.confetti = true; c.confettiCount = 18
            c.squish = true
            return c
        },
        Preset(name: tr("Bubbles")) {
            var c = EffectsConfig()
            c.direction = "up"
            c.bubbles = true; c.bubbleCount = 6
            c.flash = true; c.flashStrength = 0.35
            return c
        },
        Preset(name: tr("Jelly")) {
            var c = EffectsConfig()
            c.jelly = true; c.jellyAngle = 10
            c.squish = true; c.squishDepth = 0.82
            c.shockwave = true
            return c
        },
        Preset(name: tr("Love")) {
            var c = EffectsConfig()
            c.position = "bottom"
            c.direction = "up"
            c.hearts = true; c.heartCount = 8
            c.heartbeat = true
            c.glow = true; c.glowStrength = 0.5
            c.editStyle("hearts") { $0.colorMode = "warm" }; return c
        },
        Preset(name: tr("Winter")) {
            var c = EffectsConfig()
            c.position = "top"
            c.direction = "down"
            c.colorMode = "white"
            c.snow = true; c.snowCount = 14
            c.sweep = true
            c.editStyle("snow") { $0.colorMode = "white" }; c.editStyle("sweep") { $0.colorMode = "cool" }; return c
        },
        Preset(name: tr("Storm")) {
            var c = EffectsConfig()
            c.position = "top"
            c.direction = "down"
            c.rain = true; c.rainCount = 12
            c.lightning = true
            c.shake = true
            c.editStyle("rain") { $0.colorMode = "cool" }; return c
        },
        Preset(name: tr("Party")) {
            var c = EffectsConfig()
            c.position = "random"
            c.direction = "random"
            c.colorMode = "rainbow"
            c.fireworks = true
            c.stars = true
            c.confetti = true
            c.editStyle("confetti") { $0.colorMode = "pastel" }; c.editStyle("fireworks") { $0.colorMode = "neon" }; return c
        },
        Preset(name: tr("Cyber")) {
            var c = EffectsConfig()
            c.colorMode = "custom"; c.customColor = ThemeRGBA(hex: 0x00E5FF)
            c.glitch = true
            c.sweep = true; c.sweepDuration = 0.35
            c.underline = true
            return c
        },
        Preset(name: tr("Space")) {
            var c = EffectsConfig()
            c.colorMode = "custom"; c.customColor = ThemeRGBA(hex: 0x8F7BFF)
            c.glow = true; c.glowStrength = 0.45; c.glowSpread = 1.5
            c.setOn("twinkle", true)
            c.setOn("comet", true)
            c.setOn("galaxy", true)
            return c
        },
        Preset(name: tr("Garden")) {
            var c = EffectsConfig()
            c.direction = "down"
            c.colorMode = "rainbow"
            c.setOn("petals", true)
            c.setOn("butterflies", true)
            c.setOn("sakura", true)
            c.editStyle("petals") { $0.colorMode = "pastel" }; return c
        },
        Preset(name: tr("Arcade")) {
            var c = EffectsConfig()
            c.colorMode = "rainbow"
            c.setOn("coins", true)
            c.setOn("pixels", true)
            c.setOn("disco", true)
            c.squish = true
            return c
        },
        Preset(name: tr("Magic")) {
            var c = EffectsConfig()
            c.colorMode = "custom"; c.customColor = ThemeRGBA(hex: 0xFF8AE2)
            c.glow = true
            c.setOn("sparkler", true)
            c.setOn("twinkle", true)
            c.setOn("halo", true)
            return c
        },
        Preset(name: tr("Bounce")) {
            var c = EffectsConfig()
            c.pop = true; c.popScale = 1.5
            c.echo = true
            return c
        },
        Preset(name: tr("Sunset")) { var c = EffectsConfig.tinted(0xFF7A45); c.glow = true; c.glowSpread = 1.6; c.setOn("flames", true); c.setOn("halo", true); c.editStyle("flames") { $0.colorMode = "warm" }; c.editStyle("halo") { $0.colorMode = "pastel" }; return c },
        Preset(name: tr("Ocean")) { var c = EffectsConfig.tinted(0x2AA8FF); c.bubbles = true; c.bubbleCount = 7; c.ripple = true; c.rippleStyle = "ring"; c.setOn("splash", true); c.editStyle("bubbles") { $0.colorMode = "cool" }; c.editStyle("splash") { $0.colorMode = "cool" }; return c },
        Preset(name: tr("Forest")) { var c = EffectsConfig.tinted(0x4CD964); c.position = "bottom"; c.direction = "up"; c.setOn("leaves", true); c.setOn("fireflies", true); c.glow = true; c.glowStrength = 0.4; return c },
        Preset(name: tr("Candy")) { var c = EffectsConfig(); c.position = "random"; c.direction = "random"; c.colorMode = "rainbow"; c.pop = true; c.popScale = 1.4; c.setOn("balloons", true); c.setOn("glitter", true); c.editStyle("glitter") { $0.colorMode = "pastel" }; c.editStyle("balloons") { $0.colorMode = "neon" }; return c },
        Preset(name: tr("Lava")) { var c = EffectsConfig.tinted(0xFF4A1C); c.position = "bottom"; c.direction = "up"; c.glow = true; c.glowStrength = 0.9; c.glowSpread = 2; c.embers = true; c.smoke = true; c.shake = true; c.editStyle("embers") { $0.colorMode = "warm" }; c.editStyle("smoke") { $0.colorMode = "white" }; return c },
        Preset(name: tr("Frost")) { var c = EffectsConfig.tinted(0xBDE9FF); c.snow = true; c.snowCount = 10; c.shine = true; c.border = true; return c },
        Preset(name: tr("Thunder")) { var c = EffectsConfig.tinted(0xFFE15A); c.lightning = true; c.flash = true; c.setOn("zap", true); c.shake = true; return c },
        Preset(name: tr("Nightclub")) { var c = EffectsConfig(); c.colorMode = "rainbow"; c.beam = true; c.setOn("disco", true); c.setOn("lasers", true); c.glow = true; c.editStyle("lasers") { $0.colorMode = "neon" }; c.editStyle("disco") { $0.colorMode = "neon" }; return c },
        Preset(name: tr("Retro")) { var c = EffectsConfig.tinted(0xFF5FA2); c.setOn("pixels", true); c.setOn("coins", true); c.glitch = true; c.underline = true; return c },
        Preset(name: tr("Hacker")) { var c = EffectsConfig.tinted(0x2BFF6A); c.setOn("matrix", true); c.setOn("circuit", true); c.glitch = true; c.sweep = true; return c },
        Preset(name: tr("Gold")) { var c = EffectsConfig.tinted(0xFFC83D); c.glow = true; c.shine = true; c.setOn("coins", true); c.setOn("gems", true); return c },
        Preset(name: tr("Chrome")) { var c = EffectsConfig(); c.colorMode = "white"; c.shine = true; c.border = true; c.sweep = true; c.sweepDuration = 0.4; return c },
        Preset(name: tr("Cherry")) { var c = EffectsConfig.tinted(0xFF3B5C); c.setOn("sakura", true); c.setOn("petals", true); c.heartbeat = true; return c },
        Preset(name: tr("Mint")) { var c = EffectsConfig.tinted(0x5CF2C2); c.ripple = true; c.bubbles = true; c.bubbleCount = 4; c.shine = true; return c },
        Preset(name: tr("Lavender")) { var c = EffectsConfig.tinted(0xB79CFF); c.glow = true; c.glowSpread = 1.5; c.setOn("butterflies", true); c.setOn("dandelion", true); return c },
        Preset(name: tr("Twilight")) { var c = EffectsConfig.tinted(0x7F6BFF); c.glow = true; c.stars = true; c.starCount = 6; c.setOn("twinkle", true); c.setOn("aurora", true); return c },
        Preset(name: tr("Dawn")) { var c = EffectsConfig.tinted(0xFFB38A); c.direction = "up"; c.beam = true; c.glow = true; c.glowStrength = 0.5; c.setOn("halo", true); return c },
        Preset(name: tr("Midnight")) { var c = EffectsConfig.tinted(0x4C6FFF); c.glow = true; c.glowStrength = 0.35; c.setOn("twinkle", true); c.setOn("comet", true); return c },
        Preset(name: tr("Dream")) { var c = EffectsConfig.tinted(0xE6B8FF); c.direction = "up"; c.smoke = true; c.setOn("nebula", true); c.setOn("sparkler", true); c.jelly = true; return c },
        Preset(name: tr("Pulse")) { var c = EffectsConfig(); c.heartbeat = true; c.shockwave = true; c.glow = true; c.glowFadeOut = 0.5; return c },
        Preset(name: tr("Launch")) { var c = EffectsConfig.tinted(0xFF8A3D); c.position = "bottom"; c.direction = "up"; c.setOn("rockets", true); c.embers = true; c.drop = true; c.shake = true; return c },
        Preset(name: tr("Pinball")) { var c = EffectsConfig(); c.position = "random"; c.direction = "random"; c.colorMode = "rainbow"; c.setOn("bounce", true); c.shockwave = true; c.squish = true; c.flash = true; return c },
        Preset(name: tr("Carnival")) { var c = EffectsConfig(); c.position = "random"; c.direction = "random"; c.colorMode = "rainbow"; c.setOn("streamers", true); c.setOn("balloons", true); c.confetti = true; c.confettiCount = 12; return c },
        Preset(name: tr("Birthday")) { var c = EffectsConfig(); c.direction = "up"; c.colorMode = "rainbow"; c.setOn("balloons", true); c.confetti = true; c.fireworks = true; c.pop = true; return c },
        Preset(name: tr("Wedding")) { var c = EffectsConfig.tinted(0xFFFFFF); c.hearts = true; c.heartCount = 6; c.setOn("petals", true); c.setOn("halo", true); return c },
        Preset(name: tr("Halloween")) { var c = EffectsConfig.tinted(0xFF8A1F); c.setOn("ghosts", true); c.smoke = true; c.lightning = true; c.shake = true; return c },
        Preset(name: tr("Christmas")) { var c = EffectsConfig(); c.colorMode = "rainbow"; c.snow = true; c.stars = true; c.setOn("sparkler", true); c.glow = true; c.editStyle("snow") { $0.colorMode = "white" }; c.editStyle("stars") { $0.colorMode = "warm" }; return c },
        Preset(name: tr("Spring")) { var c = EffectsConfig(); c.direction = "right"; c.colorMode = "rainbow"; c.setOn("petals", true); c.setOn("butterflies", true); c.setOn("dandelion", true); c.editStyle("petals") { $0.colorMode = "pastel" }; c.editStyle("butterflies") { $0.colorMode = "neon" }; return c },
        Preset(name: tr("Summer")) { var c = EffectsConfig.tinted(0xFFD23D); c.beam = true; c.shine = true; c.setOn("splash", true); c.setOn("smileys", true); return c },
        Preset(name: tr("Autumn")) { var c = EffectsConfig.tinted(0xE5822B); c.position = "top"; c.direction = "down"; c.setOn("leaves", true); c.embers = true; c.glow = true; c.glowStrength = 0.4; c.editStyle("leaves") { $0.colorMode = "warm" }; return c },
        Preset(name: tr("Monsoon")) { var c = EffectsConfig.tinted(0x6FB6FF); c.position = "top"; c.direction = "down"; c.rain = true; c.rainCount = 16; c.ripple = true; c.setOn("splash", true); c.editStyle("rain") { $0.colorMode = "cool" }; c.editStyle("splash") { $0.colorMode = "cool" }; return c },
        Preset(name: tr("Blizzard")) { var c = EffectsConfig(); c.position = "top"; c.direction = "down"; c.colorMode = "white"; c.snow = true; c.snowCount = 20; c.starburst = true; c.shake = true; return c },
        Preset(name: tr("Desert")) { var c = EffectsConfig.tinted(0xF0B565); c.direction = "right"; c.setOn("static", true); c.smoke = true; c.sweep = true; return c },
        Preset(name: tr("Jungle")) { var c = EffectsConfig.tinted(0x2FD16B); c.setOn("leaves", true); c.setOn("butterflies", true); c.setOn("snake", true); c.jelly = true; c.editStyle("butterflies") { $0.colorMode = "neon" }; c.editStyle("leaves") { $0.colorMode = "warm" }; return c },
        Preset(name: tr("Volcano")) { var c = EffectsConfig.tinted(0xFF3B1F); c.position = "bottom"; c.direction = "up"; c.setOn("flames", true); c.embers = true; c.shockwave = true; c.drop = true; c.editStyle("flames") { $0.colorMode = "warm" }; c.editStyle("embers") { $0.colorMode = "warm" }; return c },
        Preset(name: tr("Stardust")) { var c = EffectsConfig.tinted(0xFFF1B8); c.setOn("comet", true); c.setOn("meteors", true); c.stars = true; c.setOn("twinkle", true); return c },
        Preset(name: tr("Future")) { var c = EffectsConfig.tinted(0x38F0FF); c.setOn("hologram", true); c.setOn("sonar", true); c.sweep = true; c.border = true; return c },
        Preset(name: tr("Samurai")) { var c = EffectsConfig.tinted(0xFF2D55); c.setOn("ninjastars", true); c.setOn("sakura", true); c.underline = true; c.flash = true; return c },
        Preset(name: tr("Pirate")) { var c = EffectsConfig.tinted(0xFFC83D); c.setOn("coins", true); c.setOn("gems", true); c.setOn("splash", true); c.jelly = true; return c },
        Preset(name: tr("Royal")) { var c = EffectsConfig.tinted(0xB48AFF); c.setOn("crown", true); c.setOn("gems", true); c.shine = true; c.glow = true; return c },
        Preset(name: tr("Casino")) { var c = EffectsConfig(); c.colorMode = "rainbow"; c.setOn("suits", true); c.setOn("dice", true); c.setOn("coins", true); c.flip = true; return c },
        Preset(name: tr("Romance")) { var c = EffectsConfig.tinted(0xFF6B9A); c.position = "bottom"; c.direction = "up"; c.hearts = true; c.heartCount = 10; c.glow = true; c.setOn("sakura", true); return c },
        Preset(name: tr("Calm")) { var c = EffectsConfig.tinted(0x8FD3FF); c.ripple = true; c.rippleDuration = 1.1; c.glow = true; c.glowStrength = 0.3; c.glowFadeOut = 1.2; return c },
        Preset(name: tr("Energy")) { var c = EffectsConfig.tinted(0xFFE600); c.setOn("zap", true); c.sparks = true; c.sparkCount = 12; c.shockwave = true; c.squish = true; return c },
        Preset(name: tr("Focus")) { var c = EffectsConfig(); c.colorMode = "white"; c.underline = true; c.border = true; c.borderFade = 0.5; return c },
        Preset(name: tr("Playful")) { var c = EffectsConfig(); c.colorMode = "rainbow"; c.setOn("smileys", true); c.setOn("yoyo", true); c.setOn("juggle", true); c.squish = true; return c },
        Preset(name: tr("Soft")) { var c = EffectsConfig.tinted(0xFFD6E8); c.glow = true; c.glowStrength = 0.4; c.glowSpread = 1.8; c.glowFadeOut = 1; c.setOn("halo", true); return c },
        Preset(name: tr("Wild")) { var c = EffectsConfig(); c.position = "random"; c.direction = "random"; c.colorMode = "rainbow"; c.setOn("dizzy", true); c.setOn("pinwheel", true); c.shake = true; c.glitch = true; c.flip = true; return c },
        Preset(name: tr("Minimal")) { var c = EffectsConfig(); c.colorMode = "white"; c.glow = true; c.glowStrength = 0.25; c.glowSpread = 0.8; return c },
        Preset(name: tr("Showtime")) { var c = EffectsConfig(); c.position = "random"; c.direction = "random"; c.colorMode = "rainbow"; c.setOn("lasers", true); c.setOn("disco", true); c.setOn("rainbowburst", true); c.fireworks = true; c.beam = true; return c },
    ]

    /// The preset the settings match, worked out once for each change (it builds every preset to compare).
    private static var presetCache: (json: String, index: Int?)?

    private var presetIndex: Int? {
        if let cache = EffectsView.presetCache, cache.json == json { return cache.index }
        let current = config
        let index = presets.firstIndex { $0.make() == current }
        EffectsView.presetCache = (json, index)
        return index
    }

    // MARK: Body

    var body: some View {
        PinnedPreview(id: "effects", height: 260, fills: true) {
            PinnedKeyboard(effects: config)
        } content: {
        GlassList {
            Section {
                GlassChoiceLink(title: tr("Style"), symbol: "wand.and.stars",
                                options: presets.indices.map { (value: $0, name: presets[$0].name) },
                                selected: presetIndex, otherName: tr("Your own mix")) { index in
                    guard presets.indices.contains(index) else { return }
                    json = presets[index].make().encoded()
                }
            } header: {
                SectionHeader(tr("Presets"), symbol: "wand.and.stars", color: .purple)
            } footer: {
                Text(tr("Touch the keyboard above to try it. A preset sets everything; change any of it below to make your own."))
            }
            .glassRows()

            Section {
                GlassChoiceLink(title: tr("Colour"), symbol: "paintpalette",
                                options: colorOptions(inherit: false),
                                selected: config.colorMode) { bind(\.colorMode).wrappedValue = $0 }
                if config.colorMode == "custom" {
                    ColorPicker(tr("Custom colour"), selection: Binding(get: { Color(config.customColor) }, set: { color in
                        var next = config
                        next.customColor = ThemeRGBA(effectColor: color)
                        json = next.encoded()
                    }), supportsOpacity: false)
                }
            } header: {
                SectionHeader(tr("Colour"), symbol: "paintpalette", color: .pink)
            } footer: {
                Text(tr("Rainbow gives every press a new colour."))
            }
            .glassRows()

            Section {
                GlassChoiceLink(title: tr("Direction"), symbol: "arrow.up.and.down.and.arrow.left.and.right",
                                options: directionOptions(inherit: false),
                                selected: config.direction) { bind(\.direction).wrappedValue = $0 }
            } header: {
                SectionHeader(tr("Direction"), symbol: "location.north.line", color: .mint)
            } footer: {
                Text(tr("Which way the effects go. Auto lets each effect go the way it was designed; Random picks a new way for every press."))
            }
            .glassRows()

            Section {
                GlassChoiceLink(title: tr("Position"), symbol: "scope",
                                options: positionOptions(inherit: false),
                                selected: config.position) { bind(\.position).wrappedValue = $0 }
            } header: {
                SectionHeader(tr("Position"), symbol: "scope", color: .cyan)
            } footer: {
                Text(tr("Where on the key the effects start. Random picks a new spot for every press."))
            }
            .glassRows()

            effect(tr("Glow"), "light.max", .orange, id: "glow", on: bind(\.glow),
                   note: tr("A light that fades in under your finger and fades out after it lifts.")) {
                GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: bind(\.glowStrength),
                            range: EffectsConfig.glowStrengthRange, step: 0.05) { DeviceMetrics.level($0, in: 0...1) }
                GlassSlider(title: tr("Spread"), symbol: "circle.dashed", value: bind(\.glowSpread),
                            range: EffectsConfig.glowSpreadRange, step: 0.1, format: times)
                GlassSlider(title: tr("Fade in"), symbol: "sunrise", value: bind(\.glowFadeIn),
                            range: EffectsConfig.glowFadeInRange, step: 0.01, format: seconds)
                GlassSlider(title: tr("Fade out"), symbol: "sunset", value: bind(\.glowFadeOut),
                            range: EffectsConfig.glowFadeOutRange, step: 0.05, format: seconds)
            }

            effect(tr("Outline light"), "square.dashed", .blue, id: "border", on: bind(\.border),
                   note: tr("A line round the key lights up and fades away.")) {
                GlassSlider(title: tr("Width"), symbol: "lineweight", value: bind(\.borderWidth),
                            range: EffectsConfig.borderWidthRange, step: 0.1) { String(format: "%.1f pt", $0) }
                GlassSlider(title: tr("Fade out"), symbol: "sunset", value: bind(\.borderFade),
                            range: EffectsConfig.borderFadeRange, step: 0.05, format: seconds)
            }

            effect(tr("Ripple"), "circle.hexagongrid.fill", .teal, id: "ripple", on: bind(\.ripple),
                   note: tr("Light spreads from the middle of the key, inside its shape, and fades away.")) {
                SegmentedChoice(title: tr("Shape"), names: [tr("Disc"), tr("Ring")],
                                selected: config.rippleStyle == "ring" ? 1 : 0) { bind(\.rippleStyle).wrappedValue = $0 == 1 ? "ring" : "disc" }
                GlassSlider(title: tr("Reach"), symbol: "arrow.up.left.and.arrow.down.right", value: bind(\.rippleReach),
                            range: EffectsConfig.rippleReachRange, step: 0.1, format: times)
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.rippleDuration),
                            range: EffectsConfig.rippleDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Shine"), "sun.max.fill", .yellow, id: "shine", on: bind(\.shine),
                   note: tr("A slanted band of light sweeps across the key.")) {
                GlassSlider(title: tr("Band width"), symbol: "arrow.left.and.right", value: bind(\.shineWidth),
                            range: EffectsConfig.shineWidthRange, step: 0.05) { String(format: "%.0f%%", $0 * 100) }
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.shineDuration),
                            range: EffectsConfig.shineDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Sparks"), "sparkles", .pink, id: "sparks", on: bind(\.sparks),
                   note: tr("Specks fly out of the key in every direction and fade.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.sparkCount),
                            range: EffectsConfig.sparkCountRange, step: 1) { "\(Int($0.rounded()))" }
                GlassSlider(title: tr("Distance"), symbol: "arrow.up.left.and.arrow.down.right", value: bind(\.sparkDistance),
                            range: EffectsConfig.sparkDistanceRange, step: 0.1, format: times)
                GlassSlider(title: tr("Size"), symbol: "circle.fill", value: bind(\.sparkSize),
                            range: EffectsConfig.sparkSizeRange, step: 0.5) { String(format: "%.1f pt", $0) }
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.sparkDuration),
                            range: EffectsConfig.sparkDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Pop"), "arrow.up.left.and.down.right.magnifyingglass", .green, id: "pop", on: bind(\.pop),
                   note: tr("The label swells (or shrinks) and springs back.")) {
                GlassSlider(title: tr("Size"), symbol: "textformat.size", value: bind(\.popScale),
                            range: EffectsConfig.popScaleRange, step: 0.05, format: times)
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.popDuration),
                            range: EffectsConfig.popDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Echo"), "text.append", .indigo, id: "echo", on: bind(\.echo),
                   note: tr("A copy of the label floats up out of the key and fades.")) {
                GlassSlider(title: tr("Rise"), symbol: "arrow.up", value: bind(\.echoRise),
                            range: EffectsConfig.echoRiseRange, step: 1) { "\(Int($0.rounded())) pt" }
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.echoDuration),
                            range: EffectsConfig.echoDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Wave"), "dot.radiowaves.left.and.right", .cyan, id: "wave", on: bind(\.wave),
                   note: tr("The keys around the pressed one light up in turn, the farther ones a moment later.")) {
                GlassSlider(title: tr("Reach"), symbol: "arrow.up.left.and.arrow.down.right", value: bind(\.waveReach),
                            range: EffectsConfig.waveReachRange, step: 0.1) { String(format: "%.1f keys", $0) }
                GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: bind(\.waveStrength),
                            range: EffectsConfig.waveStrengthRange, step: 0.05) { DeviceMetrics.level($0, in: 0...1) }
                GlassSlider(title: tr("Speed"), symbol: "speedometer", value: bind(\.waveSpeed),
                            range: EffectsConfig.waveSpeedRange, step: 0.01) { String(format: "%.0f ms/key", $0 * 1000) }
            }

            effect(tr("Shockwave"), "dot.radiowaves.right", .mint, id: "shockwave", on: bind(\.shockwave),
                   note: tr("A ring of light spreads far out over the keys around the one you press.")) {
                GlassSlider(title: tr("Reach"), symbol: "arrow.up.left.and.arrow.down.right", value: bind(\.shockReach),
                            range: EffectsConfig.shockReachRange, step: 0.1) { String(format: "%.1f keys", $0) }
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.shockDuration),
                            range: EffectsConfig.shockDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Confetti"), "gift.fill", .orange, id: "confetti", on: bind(\.confetti),
                   note: tr("Little pieces of paper are thrown up out of the key and tumble down.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.confettiCount),
                            range: EffectsConfig.confettiCountRange, step: 1) { "\(Int($0.rounded()))" }
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.confettiDuration),
                            range: EffectsConfig.confettiDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Bubbles"), "circle.grid.2x2.fill", .cyan, id: "bubbles", on: bind(\.bubbles),
                   note: tr("Bubbles float up from the key, swaying as they go.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.bubbleCount),
                            range: EffectsConfig.bubbleCountRange, step: 1) { "\(Int($0.rounded()))" }
                GlassSlider(title: tr("Rise"), symbol: "arrow.up", value: bind(\.bubbleRise),
                            range: EffectsConfig.bubbleRiseRange, step: 5) { "\(Int($0.rounded())) pt" }
            }

            effect(tr("Squish"), "arrow.down.right.and.arrow.up.left", .green, id: "squish", on: bind(\.squish),
                   note: tr("The key squashes under your finger and springs back.")) {
                GlassSlider(title: tr("Depth"), symbol: "arrow.down.to.line", value: bind(\.squishDepth),
                            range: EffectsConfig.squishDepthRange, step: 0.01) { String(format: "%.0f%%", (1 - $0) * 100) }
            }

            effect(tr("Flash"), "bolt.fill", .yellow, id: "flash", on: bind(\.flash),
                   note: tr("The key lights up in the effect colour for a moment.")) {
                GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: bind(\.flashStrength),
                            range: EffectsConfig.flashStrengthRange, step: 0.05) { DeviceMetrics.level($0, in: 0...1) }
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.flashDuration),
                            range: EffectsConfig.flashDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Jelly"), "waveform.path", .purple, id: "jelly", on: bind(\.jelly),
                   note: tr("The key wobbles like jelly, the swings getting smaller.")) {
                GlassSlider(title: tr("Swing"), symbol: "arrow.left.and.right", value: bind(\.jellyAngle),
                            range: EffectsConfig.jellyAngleRange, step: 1) { "\(Int($0.rounded()))\u{00B0}" }
            }

            effect(tr("Hearts"), "heart.fill", .pink, id: "hearts", on: bind(\.hearts),
                   note: tr("Little hearts float up from the key.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.heartCount),
                            range: EffectsConfig.heartCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Stars"), "star.fill", .yellow, id: "stars", on: bind(\.stars),
                   note: tr("Stars burst out of the key and fade.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.starCount),
                            range: EffectsConfig.starCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Snow"), "snowflake", .cyan, id: "snow", on: bind(\.snow),
                   note: tr("Snowflakes drift down past the key.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.snowCount),
                            range: EffectsConfig.snowCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Notes"), "music.note", .purple, id: "notes", on: bind(\.notes),
                   note: tr("Musical notes drift up and to the side.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.noteCount),
                            range: EffectsConfig.noteCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Fireworks"), "sparkle", .orange, id: "fireworks", on: bind(\.fireworks),
                   note: tr("Streaks burst out of the key and fall like fireworks.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.fireworkCount),
                            range: EffectsConfig.fireworkCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Starburst"), "sun.max", .yellow, id: "starburst", on: bind(\.starburst),
                   note: tr("Thin rays shoot out of the key in every direction.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.rayCount),
                            range: EffectsConfig.rayCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Rain"), "cloud.rain.fill", .blue, id: "rain", on: bind(\.rain),
                   note: tr("Drops of rain fall past the key.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.rainCount),
                            range: EffectsConfig.rainCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Embers"), "flame.fill", .red, id: "embers", on: bind(\.embers),
                   note: tr("Glowing embers rise and flicker out.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.emberCount),
                            range: EffectsConfig.emberCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Smoke"), "smoke.fill", .gray, id: "smoke", on: bind(\.smoke),
                   note: tr("Soft puffs of smoke rise from the key and grow.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.smokeCount),
                            range: EffectsConfig.smokeCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Lightning"), "bolt.circle.fill", .indigo, id: "lightning", on: bind(\.lightning),
                   note: tr("A bolt of lightning strikes up from the key.")) {
                GlassSlider(title: tr("Length"), symbol: "arrow.up.and.down", value: bind(\.lightningLength),
                            range: EffectsConfig.lightningLengthRange, step: 0.1) { String(format: "%.1f keys", $0) }
            }

            effect(tr("Orbit"), "atom", .teal, id: "orbit", on: bind(\.orbit),
                   note: tr("Little lights circle around the key.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.orbitCount),
                            range: EffectsConfig.orbitCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Spiral"), "tornado", .mint, id: "spiral", on: bind(\.spiral),
                   note: tr("Specks spiral outwards from the key.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.spiralCount),
                            range: EffectsConfig.spiralCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Heartbeat"), "heart.circle.fill", .pink, id: "heartbeat", on: bind(\.heartbeat),
                   note: tr("The key pulses twice like a heartbeat.")) {
                GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: bind(\.heartbeatStrength),
                            range: EffectsConfig.heartbeatStrengthRange, step: 0.01) { String(format: "+%.0f%%", ($0 - 1) * 100) }
            }

            effect(tr("Flip"), "rectangle.2.swap", .blue, id: "flip", on: bind(\.flip),
                   note: tr("The key flips over like a card.")) {
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.flipDuration),
                            range: EffectsConfig.flipDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Shake"), "iphone.radiowaves.left.and.right", .orange, id: "shake", on: bind(\.shake),
                   note: tr("The key shakes from side to side.")) {
                GlassSlider(title: tr("Distance"), symbol: "arrow.left.and.right", value: bind(\.shakeDistance),
                            range: EffectsConfig.shakeDistanceRange, step: 1) { "\(Int($0.rounded())) pt" }
            }

            effect(tr("Drop"), "arrow.down.circle.fill", .green, id: "drop", on: bind(\.drop),
                   note: tr("The key sinks and bounces back.")) {
                GlassSlider(title: tr("Depth"), symbol: "arrow.down.to.line", value: bind(\.dropDepth),
                            range: EffectsConfig.dropDepthRange, step: 1) { "\(Int($0.rounded())) pt" }
            }

            effect(tr("Glitch"), "waveform.path.ecg", .red, id: "glitch", on: bind(\.glitch),
                   note: tr("The key glitches with flickering colours.")) {
                GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: bind(\.glitchStrength),
                            range: EffectsConfig.glitchStrengthRange, step: 0.05) { DeviceMetrics.level($0, in: 0...1) }
            }

            effect(tr("Underline"), "underline", .cyan, id: "underline", on: bind(\.underline),
                   note: tr("A line grows along the bottom of the key and fades.")) {
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.underlineDuration),
                            range: EffectsConfig.underlineDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Neon sweep"), "arrow.triangle.2.circlepath", .teal, id: "sweep", on: bind(\.sweep),
                   note: tr("A light runs round the key's outline.")) {
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.sweepDuration),
                            range: EffectsConfig.sweepDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Beam"), "rays", .yellow, id: "beam", on: bind(\.beam),
                   note: tr("A beam of light rises from the key.")) {
                GlassSlider(title: tr("Height"), symbol: "arrow.up.to.line", value: bind(\.beamHeight),
                            range: EffectsConfig.beamHeightRange, step: 0.1) { String(format: "%.1f keys", $0) }
            }

            ForEach(EffectCatalog.all, id: \.id) { item in moreEffect(item) }

            effect(tr("Swipe trail"), "scribble", .red, id: "trail", on: bind(\.trail),
                   note: tr("The line you draw while swipe typing takes the colour and glows.")) {
                GlassSlider(title: tr("Glow"), symbol: "light.max", value: bind(\.trailGlow),
                            range: EffectsConfig.trailGlowRange, step: 0.05) { DeviceMetrics.level($0, in: 0...1) }
            }

            Section {
                Text(tr("All of the light that falls around keys is drawn under them, so it never covers a key."))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .glassRows()
        }
        .scrollContentBackground(.hidden)
        }
        .navigationTitle(tr("Effects"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// An effect of the catalog (EffectCatalog): its switch and all its settings.
    private func moreEffect(_ item: EffectEntry) -> some View {
        let on = Binding<Bool>(get: { config.isOn(item.id) }, set: { value in
            var next = config
            next.setOn(item.id, value)
            json = next.encoded()
        })
        return effect(tr(item.title), item.symbol, catalogColor(item.color), id: item.id, on: on, note: tr(item.note)) {
            ForEach(item.params, id: \.id) { param in
                GlassSlider(title: tr(param.title), symbol: param.symbol,
                            value: Binding(get: { config.setting(item, param.id) }, set: { value in
                                var next = config
                                next.set(item, param.id, value)
                                json = next.encoded()
                            }),
                            range: param.range, step: param.step, format: { param.format.text($0) })
            }
        }
    }

    private func catalogColor(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "cyan": return .cyan
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        default: return .gray
        }
    }

    /// One effect: a switch with a line of explanation, and its settings underneath while it is on.
    private func effect<Settings: View>(_ title: String, _ symbol: String, _ color: Color, id: String, on: Binding<Bool>,
                                        note: String, @ViewBuilder settings: () -> Settings) -> some View {
        Section {
            GlassToggle(title: title, subtitle: note, isOn: on, tapsAnywhere: true)
            if on.wrappedValue {
                settings()
                lookRows(id)
            }
        } header: {
            SectionHeader(title, symbol: symbol, color: color)
        }
        .glassRows()
    }
}

private extension EffectsConfig {
    /// A fresh set of effects in one fixed colour.
    static func tinted(_ hex: UInt32) -> EffectsConfig {
        var c = EffectsConfig()
        c.colorMode = "custom"
        c.customColor = ThemeRGBA(hex: hex)
        return c
    }
}

private extension ThemeRGBA {
    init(effectColor color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ value: CGFloat) -> Double { return (Double(min(max(value, 0), 1)) * 255).rounded() / 255 }
        self.init(byte(r), byte(g), byte(b), 1)
    }
}

// MARK: - Playground

/// How a key is moved while an effect plays (squish, jelly, the pop of its label); ThemePreview applies it to the
/// key it draws. Angles in degrees.
struct EffectPose: Equatable {
    var scale: CGFloat = 1
    var angle: Double = 0
    /// A turn about the horizontal axis (the flip).
    var flip: Double = 0
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0
    var labelScale: CGFloat = 1
}

/// One key's pose. Each key watches only its own, so a moving key never redraws the rest of the keyboard.
final class KeyPoseModel: ObservableObject {
    @Published var pose = EffectPose()
}

/// The poses of the preview's keys, moved as the keyboard moves its keys (the moves KeyEffectPlayer plays).
final class EffectMotions {
    private var models: [String: KeyPoseModel] = [:]

    func model(_ id: String) -> KeyPoseModel {
        if let model = models[id] { return model }
        let model = KeyPoseModel()
        models[id] = model
        return model
    }

    /// Plays `move` on the key `id`, its points shrunk by `scale` (the preview's size against the keyboard's).
    func play(_ move: KeyMove, on id: String, scale: CGFloat) {
        let model = self.model(id)
        let values = move.values
        guard values.count > 1 else { return }
        let times = move.keyTimes ?? values.indices.map { Double($0) / Double(values.count - 1) }
        func set(_ value: CGFloat) {
            switch move.part {
            case .scale: model.pose.scale = 1 + value
            case .label: model.pose.labelScale = 1 + value
            case .turn: model.pose.angle = Double(value) * 180 / .pi
            case .x: model.pose.offsetX = value * scale
            case .y: model.pose.offsetY = value * scale
            case .flip: model.pose.flip = Double(value) * 180 / .pi
            }
        }
        for index in 1..<values.count {
            let start = times[index - 1] * move.duration
            let length = max((times[index] - times[index - 1]) * move.duration, 0.001)
            DispatchQueue.main.asyncAfter(deadline: .now() + start) {
                withAnimation(move.eased ? .easeInOut(duration: length) : .linear(duration: length)) { set(values[index]) }
            }
        }
        if move.part == .flip {
            // All the way round is where it started: back to no turn, unseen.
            DispatchQueue.main.asyncAfter(deadline: .now() + move.duration + 0.02) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { set(0) }
            }
        }
    }
}

private struct EffectMotionsKey: EnvironmentKey {
    static let defaultValue: EffectMotions? = nil
}

extension EnvironmentValues {
    /// The Effects screen's moving keys (nil elsewhere).
    var effectMotions: EffectMotions? {
        get { return self[EffectMotionsKey.self] }
        set { self[EffectMotionsKey.self] = newValue }
    }
}

/// A key of the preview in its pose; `content` draws the key with its label at the given scale.
struct PosedKey<Content: View>: View {
    @ObservedObject var model: KeyPoseModel
    let content: (CGFloat) -> Content

    var body: some View {
        let pose = model.pose
        content(pose.labelScale)
            .scaleEffect(pose.scale)
            .rotationEffect(.degrees(pose.angle))
            .rotation3DEffect(.degrees(pose.flip), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .offset(x: pose.offsetX, y: pose.offsetY)
    }
}

/// Where a key was drawn (in the playground's space), for the touch and the effects to find it.
struct EffectKeyFrame: Equatable {
    var rect: CGRect
    var radius: CGFloat
    var label: String
}

struct EffectKeyFrames: PreferenceKey {
    static var defaultValue: [String: EffectKeyFrame] = [:]
    static func reduce(value: inout [String: EffectKeyFrame], nextValue: () -> [String: EffectKeyFrame]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct BoardWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// The name of the playground's coordinate space.
let effectsKeyboardSpace = "effectsKeyboard"

/// Put on a key's background: reports where the key is.
struct EffectKeyReporter: View {
    let id: String
    let label: String
    let radius: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: EffectKeyFrames.self,
                                   value: [id: EffectKeyFrame(rect: proxy.frame(in: .named(effectsKeyboardSpace)),
                                                              radius: radius, label: label)])
        }
    }
}

/// The keyboard preview with the effects played on whatever key is touched. They are drawn by the keyboard's own
/// code (KeyEffectPlayer, see EffectsStage), so they look as they do on the keyboard.
struct EffectsPlayground<Content: View>: View {
    let config: EffectsConfig
    @ViewBuilder let content: () -> Content

    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @AppStorage(SettingKey.letterSize, store: SharedStore.defaults) private var letterSize = SettingDefault.letterSize
    @State private var frames: [String: EffectKeyFrame] = [:]
    @State private var motions = EffectMotions()
    /// The preview's width. The effects are drawn at the keyboard's real size and shrunk by `scale`, so the sizes in
    /// points (specks, lines, glow, labels) come out as they do on the keyboard.
    @State private var boardWidth: CGFloat = 0

    private var scale: CGFloat {
        let real = CGFloat(DeviceMetrics.portraitWidth)
        return boardWidth > 0 && real > 0 ? boardWidth / real : 1
    }

    var body: some View {
        content()
            .background(GeometryReader { proxy in Color.clear.preference(key: BoardWidthKey.self, value: proxy.size.width) })
            .onPreferenceChange(BoardWidthKey.self) { if abs($0 - boardWidth) > 0.5 { boardWidth = $0 } }
            .onPreferenceChange(EffectKeyFrames.self) { if $0 != frames { frames = $0 } }
            .overlay(EffectsStage(config: config, frames: frames, scale: scale,
                                  accent: UIColor(Color.currentAccent(name: accentName, hex: accentHex)),
                                  letterSize: CGFloat(letterSize), motions: motions))
            .coordinateSpace(name: effectsKeyboardSpace)
            .environment(\.effectMotions, motions)
            .environment(\.layoutDirection, .leftToRight)
    }
}

/// The view that takes the touches on the preview and plays the effects (EffectsStageView).
private struct EffectsStage: UIViewRepresentable {
    let config: EffectsConfig
    let frames: [String: EffectKeyFrame]
    let scale: CGFloat
    let accent: UIColor
    let letterSize: CGFloat
    let motions: EffectMotions

    func makeUIView(context: Context) -> EffectsStageView {
        return EffectsStageView()
    }

    func updateUIView(_ view: EffectsStageView, context: Context) {
        view.motions = motions
        view.update(config: config, frames: frames, scale: scale, accent: accent, letterSize: letterSize)
    }
}

/// Every finger on the preview (several at once), and the effects of the keys they touch, drawn by KeyEffectPlayer at
/// the keyboard's size and shrunk to the preview. As on the keyboard, the light round the keys is drawn under a mask
/// that leaves every key out (so it never lands on a key), and the rest over the keys.
private final class EffectsStageView: UIView {
    private final class StageKey {
        let player = KeyEffectPlayer()
        /// Stands in for the key: the effects drawn on the key are added to it, and it moves as the key does.
        let proxy = CALayer()
        /// Holds the key's glow, under the mask.
        let glowHolder = CALayer()
        var frame = EffectKeyFrame(rect: .zero, radius: 0, label: "")
    }

    var motions: EffectMotions?
    /// Everything in the keyboard's points, shrunk to the preview by its transform.
    private let world = CALayer()
    private let glows = CALayer()
    private let glowMask = CAShapeLayer()
    private let keysLayer = CALayer()
    private let fxLayer = CALayer()
    private var keys: [String: StageKey] = [:]
    private var touchKeys: [ObjectIdentifier: String] = [:]
    private var config = EffectsConfig()
    private var frames: [String: EffectKeyFrame] = [:]
    private var scale: CGFloat = 1
    private var accent: UIColor = .systemBlue
    private var letterSize: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        world.anchorPoint = .zero
        glowMask.fillRule = .evenOdd
        glows.mask = glowMask
        for part in [glows, keysLayer, fxLayer] { world.addSublayer(part) }
        layer.addSublayer(world)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(config: EffectsConfig, frames: [String: EffectKeyFrame], scale: CGFloat, accent: UIColor, letterSize: CGFloat) {
        self.config = config
        self.accent = accent
        self.letterSize = letterSize
        let moved = frames != self.frames || abs(scale - self.scale) > 0.0001
        self.frames = frames
        self.scale = max(scale, 0.01)
        if moved { layoutWorld() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutWorld()
    }

    private func layoutWorld() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        world.bounds = CGRect(x: 0, y: 0, width: bounds.width / scale, height: bounds.height / scale)
        world.position = .zero
        world.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        for part in [glows, keysLayer, fxLayer] { part.frame = world.bounds }
        glowMask.frame = glows.bounds
        let outside = UIBezierPath(rect: world.bounds)
        for (id, frame) in frames {
            let key = keys[id] ?? makeKey(id)
            key.frame = frame
            let rect = CGRect(x: frame.rect.minX / scale, y: frame.rect.minY / scale,
                              width: frame.rect.width / scale, height: frame.rect.height / scale)
            let radius = frame.radius / scale
            key.proxy.frame = rect
            key.glowHolder.frame = rect
            key.player.bounds = CGRect(origin: .zero, size: rect.size)
            key.player.radius = radius
            key.player.frameInOverlay = rect
            key.player.layoutGlow()
            outside.append(UIBezierPath(roundedRect: rect, cornerRadius: radius))
        }
        for (id, key) in keys where frames[id] == nil {
            key.proxy.removeFromSuperlayer()
            key.glowHolder.removeFromSuperlayer()
            keys[id] = nil
        }
        glowMask.path = outside.cgPath
        CATransaction.commit()
    }

    private func makeKey(_ id: String) -> StageKey {
        let key = StageKey()
        keysLayer.addSublayer(key.proxy)
        glows.addSublayer(key.glowHolder)
        let player = key.player
        player.keyLayer = key.proxy
        player.overlay = fxLayer
        let holder = key.glowHolder
        player.installGlow = { glow in holder.addSublayer(glow) }
        player.echoImage = { [weak self, weak key] in
            guard let self = self, let key = key else { return nil }
            return self.labelImage(key.frame.label, size: key.player.bounds.size)
        }
        player.onMove = { [weak self] move in
            guard let self = self else { return }
            self.motions?.play(move, on: id, scale: self.scale)
        }
        player.onWave = { [weak self] color in self?.wave(from: id, color: color) }
        keys[id] = key
        return key
    }

    /// A key's label as the keyboard draws it (KeyView), for the echo.
    private func labelImage(_ text: String, size: CGSize) -> CGImage? {
        guard !text.isEmpty, size.width > 4, size.height > 0 else { return nil }
        let font = text.count == 1 ? UIFont.systemFont(ofSize: 23 * letterSize, weight: .light) : UIFont.systemFont(ofSize: 16)
        let attributes: [NSAttributedString.Key: Any] = [.font: font,
                                                         .foregroundColor: UIColor.label.resolvedColor(with: traitCollection)]
        let box = CGSize(width: size.width - 4, height: size.height)
        return UIGraphicsImageRenderer(size: box).image { _ in
            let measured = (text as NSString).size(withAttributes: attributes)
            (text as NSString).draw(at: CGPoint(x: (box.width - measured.width) / 2, y: (box.height - measured.height) / 2),
                                    withAttributes: attributes)
        }.cgImage
    }

    /// The wave: the keys around the pressed one pulse with its light, the farther ones a moment later.
    private func wave(from id: String, color: UIColor) {
        guard let origin = frames[id] else { return }
        let unit = max(frames.values.map { $0.rect.width }.min() ?? 40, 1)
        for (other, frame) in frames where other != id {
            let distance = hypot(frame.rect.midX - origin.rect.midX, frame.rect.midY - origin.rect.midY) / unit
            guard distance <= CGFloat(config.waveReach), let key = keys[other] else { continue }
            let fade = 1 - distance / (CGFloat(config.waveReach) + 0.5)
            key.player.config = config
            key.player.waveLight(color: color, strength: Float(config.waveStrength) * Float(fade),
                                 delay: TimeInterval(distance) * config.waveSpeed)
        }
    }

    private func press(_ id: String, _ down: Bool) {
        guard let key = keys[id] else { return }
        key.player.config = config
        key.player.accent = accent
        key.player.press(down)
    }

    private func keyID(at point: CGPoint) -> String? {
        if let hit = frames.first(where: { $0.value.rect.contains(point) }) { return hit.key }
        // Between keys: the nearest one.
        let nearest = frames.min { distance(from: point, to: $0.value.rect) < distance(from: point, to: $1.value.rect) }
        guard let best = nearest, distance(from: point, to: best.value.rect) < 24 else { return nil }
        return best.key
    }

    private func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        return hypot(max(rect.minX - point.x, 0, point.x - rect.maxX), max(rect.minY - point.y, 0, point.y - rect.maxY))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let id = keyID(at: touch.location(in: self)) else { continue }
            let held = touchKeys.values.contains(id)
            touchKeys[ObjectIdentifier(touch)] = id
            if !held { press(id, true) }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lift(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lift(touches)
    }

    private func lift(_ touches: Set<UITouch>) {
        for touch in touches {
            guard let id = touchKeys.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            if !touchKeys.values.contains(id) { press(id, false) }
        }
    }
}
