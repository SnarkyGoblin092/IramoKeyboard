import SwiftUI

/// Effects on the keys while they are pressed: a glow, a lit outline, a ripple, a shine, sparks, a pop of the label,
/// an echo of it and a wave over the neighbouring keys, each with its own settings, and a glow on the swipe trail.
/// The keyboard above is the keyboard itself (LiveKeyboard), so every effect plays there exactly as it does while typing.
struct EffectsView: View {
    @AppStorage(SettingKey.effects, store: SharedStore.defaults) private var json = SettingDefault.effects
    @AppStorage(SettingKey.effectPresets, store: SharedStore.defaults) private var savedJSON = SettingDefault.effectPresets
    /// Asking for a name to save the current effects under.
    @State private var naming = false
    @State private var newName = ""
    /// The saved preset waiting for the go-ahead to be overwritten.
    @State private var overwriting: SavedEffectPreset?

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
    private static let going: Set<String> = ["confetti", "bubbles", "echo", "hearts", "snow", "notes", "rain", "embers", "smoke"]
    private static let placed: Set<String> = ["ripple", "sparks", "echo", "shockwave", "confetti", "bubbles", "lightning", "hearts",
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

        /// `make` gives the preset's mix; every preset is played toned down (EffectsConfig.toned), so typing with
        /// several effects at once stays pleasant rather than busy.
        init(name: String, make: @escaping () -> EffectsConfig) {
            self.name = name
            self.make = { make().toned() }
        }
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
        Preset(name: tr("Nightclub")) { var c = EffectsConfig(); c.colorMode = "rainbow"; c.setOn("disco", true); c.setOn("lasers", true); c.glow = true; c.editStyle("lasers") { $0.colorMode = "neon" }; c.editStyle("disco") { $0.colorMode = "neon" }; return c },
        Preset(name: tr("Retro")) { var c = EffectsConfig.tinted(0xFF5FA2); c.setOn("pixels", true); c.setOn("coins", true); c.glitch = true; c.underline = true; return c },
        Preset(name: tr("Hacker")) { var c = EffectsConfig.tinted(0x2BFF6A); c.setOn("matrix", true); c.setOn("circuit", true); c.glitch = true; c.sweep = true; return c },
        Preset(name: tr("Gold")) { var c = EffectsConfig.tinted(0xFFC83D); c.glow = true; c.shine = true; c.setOn("coins", true); c.setOn("gems", true); return c },
        Preset(name: tr("Chrome")) { var c = EffectsConfig(); c.colorMode = "white"; c.shine = true; c.border = true; c.sweep = true; c.sweepDuration = 0.4; return c },
        Preset(name: tr("Cherry")) { var c = EffectsConfig.tinted(0xFF3B5C); c.setOn("sakura", true); c.setOn("petals", true); c.heartbeat = true; return c },
        Preset(name: tr("Mint")) { var c = EffectsConfig.tinted(0x5CF2C2); c.ripple = true; c.bubbles = true; c.bubbleCount = 4; c.shine = true; return c },
        Preset(name: tr("Lavender")) { var c = EffectsConfig.tinted(0xB79CFF); c.glow = true; c.glowSpread = 1.5; c.setOn("butterflies", true); c.setOn("dandelion", true); return c },
        Preset(name: tr("Twilight")) { var c = EffectsConfig.tinted(0x7F6BFF); c.glow = true; c.stars = true; c.starCount = 6; c.setOn("twinkle", true); c.setOn("aurora", true); return c },
        Preset(name: tr("Dawn")) { var c = EffectsConfig.tinted(0xFFB38A); c.direction = "up"; c.glow = true; c.glowStrength = 0.5; c.setOn("halo", true); c.setOn("aurora", true); return c },
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
        Preset(name: tr("Summer")) { var c = EffectsConfig.tinted(0xFFD23D); c.shine = true; c.setOn("splash", true); c.setOn("butterflies", true); return c },
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
        Preset(name: tr("Playful")) { var c = EffectsConfig(); c.colorMode = "rainbow"; c.setOn("bounce", true); c.setOn("yoyo", true); c.setOn("juggle", true); c.squish = true; return c },
        Preset(name: tr("Soft")) { var c = EffectsConfig.tinted(0xFFD6E8); c.glow = true; c.glowStrength = 0.4; c.glowSpread = 1.8; c.glowFadeOut = 1; c.setOn("halo", true); return c },
        Preset(name: tr("Wild")) { var c = EffectsConfig(); c.position = "random"; c.direction = "random"; c.colorMode = "rainbow"; c.setOn("dizzy", true); c.setOn("pinwheel", true); c.shake = true; c.glitch = true; c.flip = true; return c },
        Preset(name: tr("Minimal")) { var c = EffectsConfig(); c.colorMode = "white"; c.glow = true; c.glowStrength = 0.25; c.glowSpread = 0.8; return c },
        Preset(name: tr("Showtime")) { var c = EffectsConfig(); c.position = "random"; c.direction = "random"; c.colorMode = "rainbow"; c.setOn("lasers", true); c.setOn("disco", true); c.setOn("rainbowburst", true); c.fireworks = true; return c },
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

    /// The presets for the menu: Off first, the others in alphabetical order of their names in the app's language.
    private var presetOptions: [(value: Int, name: String)] {
        let options = presets.indices.map { (value: $0, name: presets[$0].name) }
        return [options[0]] + options.dropFirst().sorted { AppLanguage.precedes($0.name, $1.name) }
    }

    // MARK: Effects A–Z

    /// The effects with their own settings here (builtInEffect), by id with their English names; the others are
    /// EffectCatalog's. The swipe trail is not among them: it is not on the keys, so it stays last.
    private static let builtInEffects: [(id: String, title: String)] = [
        (id: "glow", title: "Glow"),
        (id: "border", title: "Outline light"),
        (id: "ripple", title: "Ripple"),
        (id: "shine", title: "Shine"),
        (id: "sparks", title: "Sparks"),
        (id: "pop", title: "Pop"),
        (id: "echo", title: "Echo"),
        (id: "wave", title: "Wave"),
        (id: "shockwave", title: "Shockwave"),
        (id: "confetti", title: "Confetti"),
        (id: "bubbles", title: "Bubbles"),
        (id: "squish", title: "Squish"),
        (id: "flash", title: "Flash"),
        (id: "jelly", title: "Jelly"),
        (id: "hearts", title: "Hearts"),
        (id: "stars", title: "Stars"),
        (id: "snow", title: "Snow"),
        (id: "notes", title: "Notes"),
        (id: "fireworks", title: "Fireworks"),
        (id: "starburst", title: "Starburst"),
        (id: "rain", title: "Rain"),
        (id: "embers", title: "Embers"),
        (id: "smoke", title: "Smoke"),
        (id: "lightning", title: "Lightning"),
        (id: "orbit", title: "Orbit"),
        (id: "spiral", title: "Spiral"),
        (id: "heartbeat", title: "Heartbeat"),
        (id: "flip", title: "Flip"),
        (id: "shake", title: "Shake"),
        (id: "drop", title: "Drop"),
        (id: "glitch", title: "Glitch"),
        (id: "underline", title: "Underline"),
        (id: "sweep", title: "Neon sweep")
    ]

    /// Every effect on the keys, these and the catalog's, in alphabetical order of their names in the app's
    /// language, worked out once for each language.
    private static var orderCache: (language: String, items: [(id: String, title: String)])?

    private var effectsByName: [(id: String, title: String)] {
        let language = AppLanguage.stored
        if let cache = EffectsView.orderCache, cache.language == language { return cache.items }
        let named: [(id: String, title: String)] = EffectsView.builtInEffects.map { (id: $0.id, title: tr($0.title)) }
            + EffectCatalog.all.map { (id: $0.id, title: tr($0.title)) }
        let items = named.sorted { AppLanguage.precedes($0.title, $1.title) }
        EffectsView.orderCache = (language, items)
        return items
    }

    // MARK: Saved presets

    private var saved: [SavedEffectPreset] { return SavedEffectPreset.decode(savedJSON) }

    /// The saved presets as they are listed: in alphabetical order of their names.
    private var savedByName: [SavedEffectPreset] {
        return saved.sorted { AppLanguage.precedes($0.name, $1.name) }
    }

    private func store(_ list: [SavedEffectPreset]) {
        savedJSON = SavedEffectPreset.encode(list)
    }

    /// Saves the current effects under `name`; one already saved under that name is overwritten.
    private func saveCurrent(as name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = saved
        let preset = SavedEffectPreset(name: trimmed, effects: json)
        if let index = list.firstIndex(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            list[index] = preset
        } else {
            list.append(preset)
        }
        store(list)
        Feedback.success()
    }

    private func overwrite(_ preset: SavedEffectPreset) {
        store(saved.map { $0.name == preset.name ? SavedEffectPreset(name: preset.name, effects: json) : $0 })
        Feedback.success()
    }

    private func load(_ preset: SavedEffectPreset) {
        json = preset.effects
        Feedback.choose()
    }

    private func delete(_ preset: SavedEffectPreset) {
        store(saved.filter { $0.name != preset.name })
        Feedback.delete()
    }

    /// A saved preset: a tap loads it; its menu overwrites or deletes it.
    private func savedRow(_ preset: SavedEffectPreset) -> some View {
        HStack {
            Button { load(preset) } label: {
                HStack {
                    Text(preset.name).foregroundColor(.primary)
                    Spacer()
                    if preset.effects == json {
                        Image(systemName: "checkmark").foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Menu {
                Button { overwriting = preset } label: {
                    Label(tr("Overwrite with current effects"), systemImage: "square.and.arrow.down.on.square")
                }
                Button(role: .destructive) { delete(preset) } label: { Label(tr("Delete"), systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .contentShape(Circle())
            }
            // The list's glass press highlight (blue, rounded rectangle) lingered after the menu closed; the menu
            // keeps only the system's own round press.
            .buttonStyle(.plain)
            .contentShape(Circle())
        }
    }

    // MARK: Body

    var body: some View {
        PinnedPreview(height: 260, fills: true) {
            LiveKeyboard(effects: config)
        } content: {
        GlassList {
            Section {
                GlassChoiceLink(title: tr("Preset"), symbol: "wand.and.stars",
                                options: presetOptions,
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
                ForEach(savedByName, id: \.name) { preset in
                    savedRow(preset)
                }
            } header: {
                SectionHeader(tr("My presets"), symbol: "tray.full", color: .indigo)
            } footer: {
                Text(tr("Tap a preset to load it; overwrite or delete it from its menu."))
            }
            .glassRows()

            Section {
                Button {
                    newName = ""
                    naming = true
                } label: {
                    Label(tr("Save current effects"), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(ActionButtonStyle())
                .glassOutsideCard()
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

            ForEach(effectsByName, id: \.id) { item in
                if let entry = EffectCatalog.entry(item.id) {
                    moreEffect(entry)
                } else {
                    builtInEffect(item.id, item.title)
                }
            }

            effect(tr("Swipe trail"), "scribble", .red, id: "trail", on: bind(\.trail),
                   note: tr("The line you draw while swipe typing takes the colour and glows.")) {
                GlassSlider(title: tr("Glow"), symbol: "light.max", value: bind(\.trailGlow),
                            range: EffectsConfig.trailGlowRange, step: 0.05) { DeviceMetrics.level($0, in: 0...1) }
            }
        }
        .scrollContentBackground(.hidden)
        }
        .navigationTitle(tr("Effects"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(tr("Save effects"), isPresented: $naming) {
            TextField(tr("Name"), text: $newName)
            Button(tr("Save")) { saveCurrent(as: newName) }
            Button(tr("Cancel"), role: .cancel) {}
        } message: {
            Text(tr("A preset with the same name is overwritten."))
        }
        .confirmationDialog(tr("Overwrite %@?", overwriting?.name ?? ""),
                            isPresented: Binding(get: { overwriting != nil }, set: { if !$0 { overwriting = nil } }),
                            titleVisibility: .visible) {
            Button(tr("Overwrite")) { if let preset = overwriting { overwrite(preset) } }
            Button(tr("Cancel"), role: .cancel) {}
        } message: {
            Text(tr("It will hold the effects as they are set now."))
        }
    }

    /// A built-in effect (builtInEffects): its switch and all its settings, under `title`.
    @ViewBuilder private func builtInEffect(_ id: String, _ title: String) -> some View {
        switch id {
        case "glow":
            effect(title, "light.max", .orange, id: "glow", on: bind(\.glow),
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
        case "border":
            effect(title, "square.dashed", .blue, id: "border", on: bind(\.border),
                   note: tr("A line round the key lights up and fades away.")) {
                GlassSlider(title: tr("Width"), symbol: "lineweight", value: bind(\.borderWidth),
                            range: EffectsConfig.borderWidthRange, step: 0.1) { String(format: "%.1f pt", $0) }
                GlassSlider(title: tr("Fade out"), symbol: "sunset", value: bind(\.borderFade),
                            range: EffectsConfig.borderFadeRange, step: 0.05, format: seconds)
            }
        case "ripple":
            effect(title, "circle.hexagongrid.fill", .teal, id: "ripple", on: bind(\.ripple),
                   note: tr("Light spreads from the middle of the key, inside its shape, and fades away.")) {
                SegmentedChoice(title: tr("Shape"), names: [tr("Disc"), tr("Ring")],
                                selected: config.rippleStyle == "ring" ? 1 : 0) { bind(\.rippleStyle).wrappedValue = $0 == 1 ? "ring" : "disc" }
                GlassSlider(title: tr("Reach"), symbol: "arrow.up.left.and.arrow.down.right", value: bind(\.rippleReach),
                            range: EffectsConfig.rippleReachRange, step: 0.1, format: times)
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.rippleDuration),
                            range: EffectsConfig.rippleDurationRange, step: 0.05, format: seconds)
            }
        case "shine":
            effect(title, "sun.max.fill", .yellow, id: "shine", on: bind(\.shine),
                   note: tr("A slanted band of light sweeps across the key.")) {
                GlassSlider(title: tr("Band width"), symbol: "arrow.left.and.right", value: bind(\.shineWidth),
                            range: EffectsConfig.shineWidthRange, step: 0.05) { String(format: "%.0f%%", $0 * 100) }
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.shineDuration),
                            range: EffectsConfig.shineDurationRange, step: 0.05, format: seconds)
            }
        case "sparks":
            effect(title, "sparkles", .pink, id: "sparks", on: bind(\.sparks),
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
        case "pop":
            effect(title, "arrow.up.left.and.down.right.magnifyingglass", .green, id: "pop", on: bind(\.pop),
                   note: tr("The label swells (or shrinks) and springs back.")) {
                GlassSlider(title: tr("Size"), symbol: "textformat.size", value: bind(\.popScale),
                            range: EffectsConfig.popScaleRange, step: 0.05, format: times)
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.popDuration),
                            range: EffectsConfig.popDurationRange, step: 0.05, format: seconds)
            }
        case "echo":
            effect(title, "text.append", .indigo, id: "echo", on: bind(\.echo),
                   note: tr("A copy of the label floats up out of the key and fades.")) {
                GlassSlider(title: tr("Rise"), symbol: "arrow.up", value: bind(\.echoRise),
                            range: EffectsConfig.echoRiseRange, step: 1) { "\(Int($0.rounded())) pt" }
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.echoDuration),
                            range: EffectsConfig.echoDurationRange, step: 0.05, format: seconds)
            }
        case "wave":
            effect(title, "dot.radiowaves.left.and.right", .cyan, id: "wave", on: bind(\.wave),
                   note: tr("The keys around the pressed one light up in turn, the farther ones a moment later.")) {
                GlassSlider(title: tr("Reach"), symbol: "arrow.up.left.and.arrow.down.right", value: bind(\.waveReach),
                            range: EffectsConfig.waveReachRange, step: 0.1) { String(format: "%.1f keys", $0) }
                GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: bind(\.waveStrength),
                            range: EffectsConfig.waveStrengthRange, step: 0.05) { DeviceMetrics.level($0, in: 0...1) }
                GlassSlider(title: tr("Speed"), symbol: "speedometer", value: bind(\.waveSpeed),
                            range: EffectsConfig.waveSpeedRange, step: 0.01) { String(format: "%.0f ms/key", $0 * 1000) }
            }
        case "shockwave":
            effect(title, "dot.radiowaves.right", .mint, id: "shockwave", on: bind(\.shockwave),
                   note: tr("A ring of light spreads far out over the keys around the one you press.")) {
                GlassSlider(title: tr("Reach"), symbol: "arrow.up.left.and.arrow.down.right", value: bind(\.shockReach),
                            range: EffectsConfig.shockReachRange, step: 0.1) { String(format: "%.1f keys", $0) }
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.shockDuration),
                            range: EffectsConfig.shockDurationRange, step: 0.05, format: seconds)
            }
        case "confetti":
            effect(title, "gift.fill", .orange, id: "confetti", on: bind(\.confetti),
                   note: tr("Little pieces of paper are thrown up out of the key and tumble down.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.confettiCount),
                            range: EffectsConfig.confettiCountRange, step: 1) { "\(Int($0.rounded()))" }
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.confettiDuration),
                            range: EffectsConfig.confettiDurationRange, step: 0.05, format: seconds)
            }
        case "bubbles":
            effect(title, "circle.grid.2x2.fill", .cyan, id: "bubbles", on: bind(\.bubbles),
                   note: tr("Bubbles float up from the key, swaying as they go.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.bubbleCount),
                            range: EffectsConfig.bubbleCountRange, step: 1) { "\(Int($0.rounded()))" }
                GlassSlider(title: tr("Rise"), symbol: "arrow.up", value: bind(\.bubbleRise),
                            range: EffectsConfig.bubbleRiseRange, step: 5) { "\(Int($0.rounded())) pt" }
            }
        case "squish":
            effect(title, "arrow.down.right.and.arrow.up.left", .green, id: "squish", on: bind(\.squish),
                   note: tr("The key squashes under your finger and springs back.")) {
                GlassSlider(title: tr("Depth"), symbol: "arrow.down.to.line", value: bind(\.squishDepth),
                            range: EffectsConfig.squishDepthRange, step: 0.01) { String(format: "%.0f%%", (1 - $0) * 100) }
            }
        case "flash":
            effect(title, "bolt.fill", .yellow, id: "flash", on: bind(\.flash),
                   note: tr("The key lights up in the effect colour for a moment.")) {
                GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: bind(\.flashStrength),
                            range: EffectsConfig.flashStrengthRange, step: 0.05) { DeviceMetrics.level($0, in: 0...1) }
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.flashDuration),
                            range: EffectsConfig.flashDurationRange, step: 0.05, format: seconds)
            }
        case "jelly":
            effect(title, "waveform.path", .purple, id: "jelly", on: bind(\.jelly),
                   note: tr("The key wobbles like jelly, the swings getting smaller.")) {
                GlassSlider(title: tr("Swing"), symbol: "arrow.left.and.right", value: bind(\.jellyAngle),
                            range: EffectsConfig.jellyAngleRange, step: 1) { "\(Int($0.rounded()))\u{00B0}" }
            }
        case "hearts":
            effect(title, "heart.fill", .pink, id: "hearts", on: bind(\.hearts),
                   note: tr("Little hearts float up from the key.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.heartCount),
                            range: EffectsConfig.heartCountRange, step: 1) { "\(Int($0.rounded()))" }
            }
        case "stars":
            effect(title, "star.fill", .yellow, id: "stars", on: bind(\.stars),
                   note: tr("Stars burst out of the key and fade.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.starCount),
                            range: EffectsConfig.starCountRange, step: 1) { "\(Int($0.rounded()))" }
            }
        case "snow":
            effect(title, "snowflake", .cyan, id: "snow", on: bind(\.snow),
                   note: tr("Snowflakes drift down past the key.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.snowCount),
                            range: EffectsConfig.snowCountRange, step: 1) { "\(Int($0.rounded()))" }
            }
        case "notes":
            effect(title, "music.note", .purple, id: "notes", on: bind(\.notes),
                   note: tr("Musical notes drift up and to the side.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.noteCount),
                            range: EffectsConfig.noteCountRange, step: 1) { "\(Int($0.rounded()))" }
            }
        case "fireworks":
            effect(title, "sparkle", .orange, id: "fireworks", on: bind(\.fireworks),
                   note: tr("Streaks burst out of the key and fall like fireworks.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.fireworkCount),
                            range: EffectsConfig.fireworkCountRange, step: 1) { "\(Int($0.rounded()))" }
            }
        case "starburst":
            effect(title, "sun.max", .yellow, id: "starburst", on: bind(\.starburst),
                   note: tr("Thin rays shoot out of the key in every direction.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.rayCount),
                            range: EffectsConfig.rayCountRange, step: 1) { "\(Int($0.rounded()))" }
            }
        case "rain":
            effect(title, "cloud.rain.fill", .blue, id: "rain", on: bind(\.rain),
                   note: tr("Drops of rain fall past the key.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.rainCount),
                            range: EffectsConfig.rainCountRange, step: 1) { "\(Int($0.rounded()))" }
            }
        case "embers":
            effect(title, "flame.fill", .red, id: "embers", on: bind(\.embers),
                   note: tr("Glowing embers rise and flicker out.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.emberCount),
                            range: EffectsConfig.emberCountRange, step: 1) { "\(Int($0.rounded()))" }
            }
        case "smoke":
            effect(title, "smoke.fill", .gray, id: "smoke", on: bind(\.smoke),
                   note: tr("Soft puffs of smoke rise from the key and grow.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.smokeCount),
                            range: EffectsConfig.smokeCountRange, step: 1) { "\(Int($0.rounded()))" }
            }
        case "lightning":
            effect(title, "bolt.circle.fill", .indigo, id: "lightning", on: bind(\.lightning),
                   note: tr("A bolt of lightning strikes up from the key.")) {
                GlassSlider(title: tr("Length"), symbol: "arrow.up.and.down", value: bind(\.lightningLength),
                            range: EffectsConfig.lightningLengthRange, step: 0.1) { String(format: "%.1f keys", $0) }
            }
        case "orbit":
            effect(title, "atom", .teal, id: "orbit", on: bind(\.orbit),
                   note: tr("Little lights circle around the key.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.orbitCount),
                            range: EffectsConfig.orbitCountRange, step: 1) { "\(Int($0.rounded()))" }
            }
        case "spiral":
            effect(title, "tornado", .mint, id: "spiral", on: bind(\.spiral),
                   note: tr("Specks spiral outwards from the key.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.spiralCount),
                            range: EffectsConfig.spiralCountRange, step: 1) { "\(Int($0.rounded()))" }
            }
        case "heartbeat":
            effect(title, "heart.circle.fill", .pink, id: "heartbeat", on: bind(\.heartbeat),
                   note: tr("The key pulses twice like a heartbeat.")) {
                GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: bind(\.heartbeatStrength),
                            range: EffectsConfig.heartbeatStrengthRange, step: 0.01) { String(format: "+%.0f%%", ($0 - 1) * 100) }
            }
        case "flip":
            effect(title, "rectangle.2.swap", .blue, id: "flip", on: bind(\.flip),
                   note: tr("The key flips over like a card.")) {
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.flipDuration),
                            range: EffectsConfig.flipDurationRange, step: 0.05, format: seconds)
            }
        case "shake":
            effect(title, "iphone.radiowaves.left.and.right", .orange, id: "shake", on: bind(\.shake),
                   note: tr("The key shakes from side to side.")) {
                GlassSlider(title: tr("Distance"), symbol: "arrow.left.and.right", value: bind(\.shakeDistance),
                            range: EffectsConfig.shakeDistanceRange, step: 1) { "\(Int($0.rounded())) pt" }
            }
        case "drop":
            effect(title, "arrow.down.circle.fill", .green, id: "drop", on: bind(\.drop),
                   note: tr("The key sinks and bounces back.")) {
                GlassSlider(title: tr("Depth"), symbol: "arrow.down.to.line", value: bind(\.dropDepth),
                            range: EffectsConfig.dropDepthRange, step: 1) { "\(Int($0.rounded())) pt" }
            }
        case "glitch":
            effect(title, "waveform.path.ecg", .red, id: "glitch", on: bind(\.glitch),
                   note: tr("The key glitches with flickering colours.")) {
                GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: bind(\.glitchStrength),
                            range: EffectsConfig.glitchStrengthRange, step: 0.05) { DeviceMetrics.level($0, in: 0...1) }
            }
        case "underline":
            effect(title, "underline", .cyan, id: "underline", on: bind(\.underline),
                   note: tr("A line grows along the bottom of the key and fades.")) {
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.underlineDuration),
                            range: EffectsConfig.underlineDurationRange, step: 0.05, format: seconds)
            }
        case "sweep":
            effect(title, "arrow.triangle.2.circlepath", .teal, id: "sweep", on: bind(\.sweep),
                   note: tr("A light runs round the key's outline.")) {
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.sweepDuration),
                            range: EffectsConfig.sweepDurationRange, step: 0.05, format: seconds)
            }
        default:
            EmptyView()
        }
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
    /// The same mix, gentler: fewer specks, softer light, smaller moves. Only the effects that are on change, so a
    /// preset with nothing on stays the plain defaults.
    func toned() -> EffectsConfig {
        var c = self
        /// `value` times `factor`, kept in `range`: whole numbers for counts, else to two places.
        func less(_ value: Double, _ factor: Double, _ range: ClosedRange<Double>, whole: Bool = false) -> Double {
            let scaled = whole ? (value * factor).rounded() : (value * factor * 100).rounded() / 100
            return min(max(scaled, range.lowerBound), range.upperBound)
        }
        /// A size or swell that rests at 1 (1.4 = 40% larger), brought `factor` of the way from 1.
        func nearer(_ value: Double, _ factor: Double, _ range: ClosedRange<Double>) -> Double {
            return less(1 + (value - 1) * factor, 1, range)
        }
        let counts = 0.6
        if c.glow {
            c.glowStrength = less(c.glowStrength, 0.7, EffectsConfig.glowStrengthRange)
            c.glowSpread = nearer(c.glowSpread, 0.5, EffectsConfig.glowSpreadRange)
        }
        if c.ripple { c.rippleReach = less(c.rippleReach, 0.85, EffectsConfig.rippleReachRange) }
        if c.sparks {
            c.sparkCount = less(c.sparkCount, counts, EffectsConfig.sparkCountRange, whole: true)
            c.sparkDistance = less(c.sparkDistance, 0.8, EffectsConfig.sparkDistanceRange)
        }
        if c.pop { c.popScale = nearer(c.popScale, 0.6, EffectsConfig.popScaleRange) }
        if c.echo { c.echoRise = less(c.echoRise, 0.75, EffectsConfig.echoRiseRange, whole: true) }
        if c.wave {
            c.waveStrength = less(c.waveStrength, 0.7, EffectsConfig.waveStrengthRange)
            c.waveReach = less(c.waveReach, 0.8, EffectsConfig.waveReachRange)
        }
        if c.shockwave { c.shockReach = less(c.shockReach, 0.75, EffectsConfig.shockReachRange) }
        if c.confetti { c.confettiCount = less(c.confettiCount, counts, EffectsConfig.confettiCountRange, whole: true) }
        if c.bubbles {
            c.bubbleCount = less(c.bubbleCount, counts, EffectsConfig.bubbleCountRange, whole: true)
            c.bubbleRise = less(c.bubbleRise, 0.75, EffectsConfig.bubbleRiseRange, whole: true)
        }
        if c.squish { c.squishDepth = nearer(c.squishDepth, 0.6, EffectsConfig.squishDepthRange) }
        if c.flash { c.flashStrength = less(c.flashStrength, 0.65, EffectsConfig.flashStrengthRange) }
        if c.jelly { c.jellyAngle = less(c.jellyAngle, 0.6, EffectsConfig.jellyAngleRange, whole: true) }
        if c.hearts { c.heartCount = less(c.heartCount, counts, EffectsConfig.heartCountRange, whole: true) }
        if c.stars { c.starCount = less(c.starCount, counts, EffectsConfig.starCountRange, whole: true) }
        if c.snow { c.snowCount = less(c.snowCount, counts, EffectsConfig.snowCountRange, whole: true) }
        if c.notes { c.noteCount = less(c.noteCount, counts, EffectsConfig.noteCountRange, whole: true) }
        if c.fireworks { c.fireworkCount = less(c.fireworkCount, counts, EffectsConfig.fireworkCountRange, whole: true) }
        if c.starburst { c.rayCount = less(c.rayCount, counts, EffectsConfig.rayCountRange, whole: true) }
        if c.rain { c.rainCount = less(c.rainCount, counts, EffectsConfig.rainCountRange, whole: true) }
        if c.embers { c.emberCount = less(c.emberCount, counts, EffectsConfig.emberCountRange, whole: true) }
        if c.smoke { c.smokeCount = less(c.smokeCount, counts, EffectsConfig.smokeCountRange, whole: true) }
        if c.lightning { c.lightningLength = less(c.lightningLength, 0.75, EffectsConfig.lightningLengthRange) }
        if c.orbit { c.orbitCount = less(c.orbitCount, counts, EffectsConfig.orbitCountRange, whole: true) }
        if c.spiral { c.spiralCount = less(c.spiralCount, counts, EffectsConfig.spiralCountRange, whole: true) }
        if c.heartbeat { c.heartbeatStrength = nearer(c.heartbeatStrength, 0.6, EffectsConfig.heartbeatStrengthRange) }
        if c.shake { c.shakeDistance = less(c.shakeDistance, 0.6, EffectsConfig.shakeDistanceRange, whole: true) }
        if c.drop { c.dropDepth = less(c.dropDepth, 0.6, EffectsConfig.dropDepthRange, whole: true) }
        if c.glitch { c.glitchStrength = less(c.glitchStrength, 0.7, EffectsConfig.glitchStrengthRange) }
        for item in EffectCatalog.all where c.isOn(item.id) {
            guard let count = item.params.first(where: { $0.id == "count" }) else { continue }
            c.set(item, "count", less(c.setting(item, "count"), counts, count.range, whole: true))
        }
        return c
    }

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

/// A mix of effects saved under a name (the Effects screen's My presets), kept as JSON under SettingKey.effectPresets.
struct SavedEffectPreset: Codable, Hashable {
    var name: String
    /// The effects as EffectsConfig stores them (empty: all off).
    var effects: String

    static func decode(_ text: String) -> [SavedEffectPreset] {
        guard !text.isEmpty, let data = text.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([SavedEffectPreset].self, from: data)) ?? []
    }

    static func encode(_ list: [SavedEffectPreset]) -> String {
        guard !list.isEmpty, let data = try? JSONEncoder().encode(list) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
