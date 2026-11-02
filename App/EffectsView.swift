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
                            options: ["inherit"].map { (value: $0, name: colorName($0)) } + colorModes.map { (value: $0, name: colorName($0)) },
                            selected: style.colorMode) { mode in editStyle(id) { $0.colorMode = mode } }
            if style.colorMode == "custom" {
                ColorPicker(tr("Custom colour"), selection: Binding(get: { Color(style.customColor) }, set: { color in
                    editStyle(id) { $0.customColor = ThemeRGBA(effectColor: color) }
                }), supportsOpacity: false)
            }
        }
        if isCatalog || EffectsView.going.contains(id) {
            GlassChoiceLink(title: tr("Direction"), symbol: "arrow.up.and.down.and.arrow.left.and.right",
                            options: [(value: "inherit", name: tr("Same as all effects"))] + directionNames.map { (value: $0.mode, name: $0.name) },
                            selected: style.direction) { value in editStyle(id) { $0.direction = value } }
        }
        if isCatalog || EffectsView.placed.contains(id) {
            GlassChoiceLink(title: tr("Position"), symbol: "scope",
                            options: [(value: "inherit", name: tr("Same as all effects"))] + positionNames.map { (value: $0.mode, name: $0.name) },
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

    private var presetIndex: Int? {
        let current = config
        return presets.firstIndex { $0.make() == current }
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
                                options: colorModes.map { (value: $0, name: colorName($0)) },
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
                                options: directionNames.map { (value: $0.mode, name: $0.name) },
                                selected: config.direction) { bind(\.direction).wrappedValue = $0 }
            } header: {
                SectionHeader(tr("Direction"), symbol: "location.north.line", color: .mint)
            } footer: {
                Text(tr("Which way the effects go. Auto lets each effect go the way it was designed; Random picks a new way for every press."))
            }
            .glassRows()

            Section {
                GlassChoiceLink(title: tr("Position"), symbol: "scope",
                                options: positionNames.map { (value: $0.mode, name: $0.name) },
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

// MARK: - Preview

/// A transient view: it appears at its start state and animates to its end state once (a new `.id` replays it).
struct Burst<Content: View>: View {
    let duration: Double
    var delay = 0.0
    /// The animation for a given duration.
    var curve: (Double) -> Animation = { .easeOut(duration: $0) }
    @ViewBuilder let content: (Bool) -> Content
    @State private var done = false

    var body: some View {
        content(done)
            .onAppear { withAnimation(curve(max(duration, 0.05)).delay(delay)) { done = true } }
    }
}

/// A pulse of light: rises quickly, then fades over `fade`, after `delay`.
struct Pulse: View {
    let strength: Double
    let fade: Double
    let delay: Double
    let tint: Color
    var radius: CGFloat = 9
    @State private var up = false
    @State private var down = false

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(tint.opacity(up && !down ? strength : 0))
            .shadow(color: tint.opacity(up && !down ? strength : 0), radius: radius)
            .onAppear {
                withAnimation(.easeOut(duration: 0.12).delay(delay)) { up = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.12) {
                    withAnimation(.easeIn(duration: fade)) { down = true }
                }
            }
    }
}

// MARK: - Playground

/// How a key is moved while an effect plays (squish, jelly); ThemePreview applies it to the key it draws.
struct EffectPose: Equatable {
    var scale: CGFloat = 1
    var angle: Double = 0
    /// A turn about the horizontal axis, in degrees (the flip).
    var flip: Double = 0
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0
}

private struct EffectPosesKey: EnvironmentKey {
    static let defaultValue: [String: EffectPose] = [:]
}

extension EnvironmentValues {
    var effectPoses: [String: EffectPose] {
        get { return self[EffectPosesKey.self] }
        set { self[EffectPosesKey.self] = newValue }
    }
}

/// A move along a throw: sideways `dx`, up or down `dy`, and gravity pulling down, as `progress` goes from 0 to 1.
private struct Ballistic: GeometryEffect {
    var progress: CGFloat
    let dx: CGFloat
    let dy: CGFloat
    let gravity: CGFloat
    var turn: CGFloat = 0

    var animatableData: CGFloat {
        get { return progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = progress
        let offset = EffectDirection.turn(CGPoint(x: dx * t, y: dy * t + gravity * t * t / 2), by: turn)
        return ProjectionTransform(CGAffineTransform(translationX: offset.x, y: offset.y))
    }
}

/// A move along any path, `path(progress)` being the offset from where the view sits.
private struct Along: GeometryEffect {
    var progress: CGFloat
    let path: (CGFloat) -> CGPoint

    var animatableData: CGFloat {
        get { return progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let point = path(progress)
        return ProjectionTransform(CGAffineTransform(translationX: point.x, y: point.y))
    }
}

/// Shows its content only once `delay` seconds have passed.
private struct Later<Content: View>: View {
    let delay: Double
    @ViewBuilder let content: () -> Content
    @State private var shown: Bool

    init(delay: Double, @ViewBuilder content: @escaping () -> Content) {
        self.delay = delay
        self.content = content
        _shown = State(initialValue: delay <= 0)
    }

    var body: some View {
        Group {
            if shown { content() } else { Color.clear }
        }
        .onAppear {
            guard !shown else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { shown = true }
        }
    }
}

/// A drawn picture of the particle effects (EffectArt) as a SwiftUI shape.
private struct EffectArtShape: Shape {
    let art: EffectArt

    func path(in rect: CGRect) -> Path {
        return Path(art.path(side: rect.width)).offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// A steady number in 0..<1 for (index, salt), so a redrawn view keeps its pieces where they were.
private func unit(_ index: Int, _ salt: Double) -> Double {
    let x = sin(Double(index) * 12.9898 + salt * 78.233) * 43758.5453
    return x - floor(x)
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

/// Every finger on the keyboard, several at once (SwiftUI's drag follows only one).
private struct EffectsTouchCatcher: UIViewRepresentable {
    let began: (Int, CGPoint) -> Void
    let ended: (Int) -> Void

    final class CatcherView: UIView {
        var began: ((Int, CGPoint) -> Void)?
        var ended: ((Int) -> Void)?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches { began?(ObjectIdentifier(touch).hashValue, touch.location(in: self)) }
        }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches { ended?(ObjectIdentifier(touch).hashValue) }
        }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches { ended?(ObjectIdentifier(touch).hashValue) }
        }
    }

    func makeUIView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        view.began = began
        view.ended = ended
        return view
    }

    func updateUIView(_ view: CatcherView, context: Context) {
        view.began = began
        view.ended = ended
    }
}

/// The keyboard preview with the effects played on whatever key is touched, as the keyboard does: the light is
/// drawn around the keys only (never over one), the rest on the key itself.
struct EffectsPlayground<Content: View>: View {
    let config: EffectsConfig
    @ViewBuilder let content: () -> Content

    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @State private var frames: [String: EffectKeyFrame] = [:]
    @State private var hue = 0.0
    @State private var counter = 0
    /// The key each finger is on, the keys being held with the colour of their press, and what restarts each
    /// key's one-shot effects.
    @State private var touchKeys: [Int: String] = [:]
    @State private var down: [String: Color] = [:]
    @State private var tints: [String: Color] = [:]
    /// The presses of each key whose effects are still playing, each with its own colour: a new press never cuts
    /// the effects of an earlier one short.
    @State private var plays: [String: [Play]] = [:]
    @State private var waves: [String: PulseRequest] = [:]
    @State private var poses: [String: EffectPose] = [:]
    /// The preview's width. The effects are drawn at the keyboard's real size and shrunk by `scale`, so the sizes in
    /// points (specks, lines, glow, labels) come out as they do on the keyboard instead of exaggerated.
    @State private var boardWidth: CGFloat = 0

    private var scale: CGFloat {
        let real = CGFloat(DeviceMetrics.portraitWidth)
        return boardWidth > 0 && real > 0 ? boardWidth / real : 1
    }

    struct Play: Equatable {
        let tick: Int
        let tint: Color
    }

    struct PulseRequest {
        let tick: Int
        let delay: Double
        let strength: Double
        let tint: Color
    }

    var body: some View {
        content()
            .background(GeometryReader { proxy in Color.clear.preference(key: BoardWidthKey.self, value: proxy.size.width) })
            .onPreferenceChange(BoardWidthKey.self) { if abs($0 - boardWidth) > 0.5 { boardWidth = $0 } }
            .onPreferenceChange(EffectKeyFrames.self) { frames = $0 }
            .overlay(
                ZStack {
                    glowLayer
                    keyEffects
                    EffectsTouchCatcher(began: { touch, point in press(touch, at: point) }, ended: { release($0) })
                }
            )
            .coordinateSpace(name: effectsKeyboardSpace)
            .environment(\.effectPoses, poses)
            .environment(\.layoutDirection, .leftToRight)
    }

    private var ids: [String] { return frames.keys.sorted() }

    private var keyEffects: some View {
        ZStack {
            ForEach(ids, id: \.self) { id in
                if let frame = frames[id] {
                    ForEach(plays[id] ?? [], id: \.tick) { play in
                        EffectsKeyFX(config: config, frame: frame, accent: Color.currentAccent(name: accentName, hex: accentHex),
                                     tick: play.tick, scale: scale)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// The lights around the keys: a glow under the finger and the wave, with every key's shape cut out.
    private var glowLayer: some View {
        ZStack {
            ForEach(ids, id: \.self) { id in
                if let frame = frames[id] {
                    glow(frame, tint: tints[id] ?? .clear, lit: config.glow && down[id] != nil, wave: waves[id])
                }
            }
        }
        .mask(cutout)
        .allowsHitTesting(false)
    }

    private func glow(_ frame: EffectKeyFrame, tint: Color, lit: Bool, wave: PulseRequest?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: frame.radius, style: .continuous)
                .fill(tint.opacity(lit ? config.glowStrength : 0))
                .shadow(color: tint.opacity(lit ? config.glowStrength : 0), radius: 9 * config.glowSpread * scale)
            if let wave = wave {
                Pulse(strength: wave.strength, fade: max(config.glowFadeOut, 0.3), delay: wave.delay, tint: wave.tint,
                      radius: 9 * scale)
                    .id(wave.tick)
            }
        }
        .frame(width: frame.rect.width, height: frame.rect.height)
        .position(x: frame.rect.midX, y: frame.rect.midY)
    }

    /// Everything but the keys.
    private var cutout: some View {
        Rectangle().fill(Color.black)
            .overlay(
                ZStack {
                    ForEach(ids, id: \.self) { id in
                        if let frame = frames[id] {
                            RoundedRectangle(cornerRadius: frame.radius, style: .continuous)
                                .frame(width: frame.rect.width, height: frame.rect.height)
                                .position(x: frame.rect.midX, y: frame.rect.midY)
                        }
                    }
                }
                .blendMode(.destinationOut)
            )
            .compositingGroup()
    }

    private func key(at point: CGPoint) -> String? {
        if let hit = frames.first(where: { $0.value.rect.contains(point) }) { return hit.key }
        // Between keys: the nearest one.
        let nearest = frames.min { distance(from: point, to: $0.value.rect) < distance(from: point, to: $1.value.rect) }
        guard let best = nearest, distance(from: point, to: best.value.rect) < 24 else { return nil }
        return best.key
    }

    private func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        return hypot(max(rect.minX - point.x, 0, point.x - rect.maxX), max(rect.minY - point.y, 0, point.y - rect.maxY))
    }

    /// The colour of one press of the effect `id`: its own colour choice, else the one for all.
    private func resolve(_ id: String) -> Color {
        let mode = config.mode(for: id)
        switch mode {
        case "white":
            return .white
        case "custom":
            return Color(config.custom(for: id))
        case "accent":
            return Color.currentAccent(name: accentName, hex: accentHex)
        case "rainbow":
            hue = (hue + 0.11).truncatingRemainder(dividingBy: 1)
            let tint = EffectPalette.tint(mode, CGFloat(hue))
            return Color(hue: Double(tint.h), saturation: Double(tint.s), brightness: Double(tint.b))
        default:
            let tint = EffectPalette.tint(mode, CGFloat.random(in: 0..<1))
            return Color(hue: Double(tint.h), saturation: Double(tint.s), brightness: Double(tint.b))
        }
    }

    private func press(_ touch: Int, at point: CGPoint) {
        guard let id = key(at: point), let frame = frames[id] else { return }
        touchKeys[touch] = id
        guard down[id] == nil else { return }
        let tint = resolve("glow")
        tints[id] = tint
        counter += 1
        let tick = counter
        plays[id, default: []].append(Play(tick: tick, tint: tint))
        // Long enough for the slowest effect to finish.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { plays[id]?.removeAll { $0.tick == tick } }
        withAnimation(.easeOut(duration: max(config.glowFadeIn, 0.001))) { down[id] = tint }
        if config.squish { squish(id) }
        if config.jelly { jelly(id) }
        if config.heartbeat {
            let beat = CGFloat(config.heartbeatStrength)
            play(id, [beat, 1, beat, 1], every: 0.12) { pose, value in pose.scale = value }
        }
        if config.shake {
            let d = CGFloat(config.shakeDistance) * scale
            play(id, [-d, d, -d * 0.7, d * 0.5, -d * 0.2, 0], every: 0.05) { pose, value in pose.offsetX = value }
        }
        if config.drop {
            let d = CGFloat(config.dropDepth) * scale
            play(id, [d, -d * 0.35, d * 0.12, 0], every: 0.09) { pose, value in pose.offsetY = value }
        }
        if config.glitch {
            let d = CGFloat(config.glitchStrength) * 6 * scale
            play(id, [-d, d * 0.8, -d * 0.5, d * 0.6, 0], every: 0.045) { pose, value in pose.offsetX = value }
        }
        if config.flip { flip(id) }
        if config.wave {
            let waveTint = resolve("wave")
            let unit = max(frames.values.map { $0.rect.width }.min() ?? 40, 1)
            for (other, otherFrame) in frames where other != id {
                let apart = hypot(otherFrame.rect.midX - frame.rect.midX, otherFrame.rect.midY - frame.rect.midY) / unit
                guard apart <= config.waveReach else { continue }
                waves[other] = PulseRequest(tick: counter, delay: apart * config.waveSpeed,
                                            strength: config.waveStrength * (1 - apart / (config.waveReach + 0.5)), tint: waveTint)
            }
        }
    }

    /// The key squashes, then springs back.
    private func squish(_ id: String) {
        withAnimation(.easeOut(duration: 0.1)) { poses[id, default: EffectPose()].scale = CGFloat(config.squishDepth) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.interpolatingSpring(stiffness: 260, damping: 8)) { poses[id, default: EffectPose()].scale = 1 }
        }
    }

    /// Moves a key's pose through `values` one after another, `every` seconds apart.
    private func play(_ id: String, _ values: [CGFloat], every: Double, _ set: @escaping (inout EffectPose, CGFloat) -> Void) {
        for (step, value) in values.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * every) {
                withAnimation(.easeInOut(duration: every)) { set(&poses[id, default: EffectPose()], value) }
            }
        }
    }

    /// The key turns over once, then is back to normal.
    private func flip(_ id: String) {
        let duration = config.flipDuration
        withAnimation(.easeInOut(duration: duration)) { poses[id, default: EffectPose()].flip = 360 }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { poses[id, default: EffectPose()].flip = 0 }
        }
    }

    /// The key swings back and forth, less each time.
    private func jelly(_ id: String) {
        let angle = config.jellyAngle
        let swings = [angle, -angle * 0.8, angle * 0.5, -angle * 0.25, 0]
        for (step, swing) in swings.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) { poses[id, default: EffectPose()].angle = swing }
            }
        }
    }

    private func release(_ touch: Int) {
        guard let id = touchKeys.removeValue(forKey: touch) else { return }
        withAnimation(.easeIn(duration: max(config.glowFadeOut, 0.001))) { down[id] = nil }
    }
}

/// The effects that play on the key itself, drawn where the key is.
private struct EffectsKeyFX: View {
    let config: EffectsConfig
    let frame: EffectKeyFrame
    let accent: Color
    let tick: Int
    /// The preview's size against the keyboard's: everything is drawn at the keyboard's size, then shrunk by this.
    let scale: CGFloat

    private var shape: RoundedRectangle { return RoundedRectangle(cornerRadius: frame.radius / scale, style: .continuous) }

    var body: some View {
        let width = frame.rect.width / scale
        let height = frame.rect.height / scale
        let borderTint = color("border")
        let sweepTint = color("sweep")
        ZStack {
            // Effects that stay inside the key's shape.
            ZStack {
                if config.ripple { ripple(width: width).offset(x: start("ripple").x, y: start("ripple").y) }
                if config.shine { shine(width: width, height: height) }
                if config.flash { flash() }
                if config.lightning { lightningFlash() }
                if config.underline { underline(width: width, height: height) }
                if config.glitch { glitchSlabs() }
            }
            .frame(width: width, height: height)
            .clipShape(shape)
            if config.border {
                Burst(duration: config.borderFade, curve: { .easeIn(duration: $0) }) { done in
                    shape.strokeBorder(borderTint, lineWidth: config.borderWidth).opacity(done ? 0 : 1)
                }
                .id(tick)
                .frame(width: width, height: height)
            }
            if config.echo && !frame.label.isEmpty {
                Burst(duration: config.echoDuration) { done in
                    Text(frame.label).font(.system(size: 22, weight: .medium))
                        .offset(x: done ? EffectDirection.turn(CGPoint(x: 0, y: -config.echoRise), by: turn("echo")).x : 0,
                                y: done ? EffectDirection.turn(CGPoint(x: 0, y: -config.echoRise), by: turn("echo")).y : 0)
                        .opacity(done ? 0 : 0.85)
                }
                .id(tick)
                .offset(x: start("echo").x, y: start("echo").y)
            }
            if config.pop && !frame.label.isEmpty {
                Burst(duration: config.popDuration, curve: { _ in .interpolatingSpring(stiffness: 260, damping: 8) }) { done in
                    Text(frame.label).font(.system(size: 22, weight: .medium)).scaleEffect(done ? 1 : config.popScale)
                }
                .id(tick)
            }
            if config.sparks { sparks(width: width).offset(x: start("sparks").x, y: start("sparks").y) }
            if config.shockwave { shockwave(width: width).offset(x: start("shockwave").x, y: start("shockwave").y) }
            if config.confetti { confetti(width: width).offset(x: start("confetti").x, y: start("confetti").y) }
            if config.bubbles { bubbles(width: width).offset(x: start("bubbles").x, y: start("bubbles").y) }
            if config.sweep {
                Burst(duration: config.sweepDuration, curve: { .linear(duration: $0) }) { done in
                    shape.trim(from: done ? 0.85 : 0, to: done ? 1 : 0.15)
                        .stroke(sweepTint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .opacity(done ? 0 : 1)
                }
                .id(tick)
                .frame(width: width, height: height)
            }
            if config.lightning { lightning(width: width, height: height).offset(x: start("lightning").x, y: start("lightning").y) }
            if config.beam { beam(width: width).offset(x: start("beam").x, y: start("beam").y) }
            particles
        }
        .frame(width: width, height: height)
        .scaleEffect(scale)
        .position(x: frame.rect.midX, y: frame.rect.midY)
    }

    /// Where this press's effect `id` starts on the key, from the middle (its position setting).
    private func start(_ id: String) -> CGPoint {
        var draws = 0
        return EffectPosition.offset(config.position(for: id),
                                     size: CGSize(width: frame.rect.width / scale, height: frame.rect.height / scale),
                                     random: { draws += 1; return CGFloat(unit(tick, Double(41 + draws))) })
    }

    /// The colour of the effect `id` for this press: its own colour choice, else the one for all.
    private func color(_ id: String) -> Color {
        let mode = config.mode(for: id)
        switch mode {
        case "white": return .white
        case "custom": return Color(config.custom(for: id))
        case "accent": return accent
        default:
            let salt = Double(id.utf8.reduce(7) { ($0 &* 31 &+ Int($1)) % 997 })
            let tint = EffectPalette.tint(mode, CGFloat(unit(tick, salt)))
            return Color(hue: Double(tint.h), saturation: Double(tint.s), brightness: Double(tint.b))
        }
    }

    /// The colour of one speck (`hue` picks it from the palette when the effect gives each speck its own colour).
    private func speckColor(_ id: String, _ hue: Double, _ base: Color) -> Color {
        let mode = config.mode(for: id)
        guard EffectPalette.isMulti(mode) else { return base }
        let tint = EffectPalette.tint(mode, CGFloat(hue))
        return Color(hue: Double(tint.h), saturation: Double(tint.s), brightness: Double(tint.b))
    }

    private func underline(width: CGFloat, height: CGFloat) -> some View {
        let tint = color("underline")
        return Burst(duration: config.underlineDuration) { done in
            Capsule().fill(tint).frame(width: width * 0.8, height: 3)
                .scaleEffect(x: done ? 1 : 0.05, y: 1)
                .opacity(done ? 0 : 1)
                .offset(y: height / 2 - 4)
        }
        .id(tick)
    }

    /// Pink and cyan copies of the key flicker over it.
    private func glitchSlabs() -> some View {
        let strength = config.glitchStrength
        return Burst(duration: 0.26, curve: { .linear(duration: $0) }) { done in
            ZStack {
                Color.pink.opacity(0.4 * strength).offset(x: -3)
                Color.cyan.opacity(0.4 * strength).offset(x: 3)
            }
            .opacity(done ? 0 : 1)
        }
        .id(tick)
    }

    /// A forked bolt strikes down onto the key (EffectBolt): glow, colour and a white core, fading.
    private func lightning(width: CGFloat, height: CGFloat) -> some View {
        let tint = color("lightning")
        let salt = tick * 7
        let bolt = EffectBolt.make(length: width * CGFloat(config.lightningLength), width: width) { index, _ in
            CGFloat(unit(index + salt, 21))
        }
        let centre = CGPoint(x: width / 2, y: height / 2)
        func line(_ points: [[CGPoint]]) -> Path {
            var path = Path()
            for run in points {
                guard let first = run.first else { continue }
                path.move(to: CGPoint(x: centre.x + first.x, y: centre.y + first.y))
                for point in run.dropFirst() { path.addLine(to: CGPoint(x: centre.x + point.x, y: centre.y + point.y)) }
            }
            return path
        }
        let main = line([bolt.main])
        let forks = line(bolt.forks)
        let round = { (width: CGFloat) in StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round) }
        return Burst(duration: 0.45, curve: { .easeIn(duration: $0) }) { done in
            ZStack {
                main.stroke(tint.opacity(0.3), style: round(14))
                main.stroke(tint.opacity(0.5), style: round(8))
                main.stroke(tint, style: round(3.5))
                main.stroke(Color.white, style: round(1.5))
                forks.stroke(tint.opacity(0.3), style: round(8))
                forks.stroke(tint.opacity(0.5), style: round(4))
                forks.stroke(tint, style: round(1.8))
                forks.stroke(Color.white, style: round(0.8))
            }
            .opacity(done ? 0 : 1)
        }
        .id(tick)
    }

    private func beam(width: CGFloat) -> some View {
        let tint = color("beam")
        let reach = width * CGFloat(config.beamHeight)
        // The beam stands on the key's middle (the middle of this view), and turns about it.
        return VStack(spacing: 0) {
            Burst(duration: 0.5) { done in
                Rectangle()
                    .fill(LinearGradient(colors: [tint.opacity(0.8), tint.opacity(0)], startPoint: .bottom, endPoint: .top))
                    .frame(width: width * 0.5, height: reach)
                    .scaleEffect(x: 1, y: done ? 1 : 0.15, anchor: .bottom)
                    .opacity(done ? 0 : 1)
            }
            Color.clear.frame(width: 1, height: reach)
        }
        .rotationEffect(.radians(Double(turn("beam"))))
        .id(tick)
    }

    // The particle effects (EffectParticles), as the keyboard plays them.

    private var particles: some View {
        let specs = EffectParticles.make(config, keySize: CGSize(width: frame.rect.width / scale, height: frame.rect.height / scale)) { index, salt in CGFloat(unit(index + tick * 13, Double(salt))) }
        return ZStack {
            ForEach(0..<specs.count, id: \.self) { index in
                Later(delay: specs[index].delay) { particle(specs[index]) }
            }
        }
        .id(tick)
    }

    private func particle(_ spec: EffectParticle) -> some View {
        let color: Color = spec.tint.map { Color(hue: Double($0.h), saturation: Double($0.s), brightness: Double($0.b)) } ?? accent
        return Burst(duration: spec.duration, curve: { .linear(duration: $0) }) { done in
            particleShape(spec, color: color)
                .rotationEffect(.radians((spec.isOriented ? Double(spec.tilt) : 0) + (done ? Double(spec.spin) : 0)))
                .scaleEffect(done ? spec.scaleTo : spec.scaleFrom)
                .modifier(Along(progress: done ? 1 : 0, path: spec.path))
                .opacity(done ? 0 : Double(spec.peak))
        }
    }

    @ViewBuilder private func particleShape(_ spec: EffectParticle, color: Color) -> some View {
        switch spec.shape {
        case .art(let art):
            EffectArtShape(art: art).fill(color, style: FillStyle(eoFill: art.cutsHoles))
                .frame(width: spec.size, height: spec.size)
        case .dot:
            Circle().fill(color).frame(width: spec.size, height: spec.size)
        case .streak(let angle):
            Capsule().fill(color).frame(width: spec.size, height: 2).rotationEffect(.radians(Double(angle)))
        case .drop:
            Capsule()
                .fill(LinearGradient(colors: [color.opacity(0), color], startPoint: .top, endPoint: .bottom))
                .frame(width: 2, height: spec.size)
        case .soft:
            Circle().fill(color.opacity(0.35)).frame(width: spec.size, height: spec.size).blur(radius: 3)
        case .ember:
            Circle().fill(color).frame(width: spec.size, height: spec.size).shadow(color: color, radius: 3)
        case .ring:
            Circle().strokeBorder(color, lineWidth: 2).frame(width: spec.size, height: spec.size)
        case .square:
            Rectangle().fill(color).frame(width: spec.size, height: spec.size)
        case .bar:
            Rectangle().fill(color).frame(width: spec.size, height: spec.size * 0.4)
        }
    }

    /// The key flashes white as the bolt strikes it.
    private func lightningFlash() -> some View {
        return Burst(duration: 0.3, curve: { .easeIn(duration: $0) }) { done in
            Color.white.opacity(done ? 0 : 0.55)
        }
        .id(tick)
    }

    private func flash() -> some View {
        let tint = color("flash")
        return Burst(duration: config.flashDuration, curve: { .easeIn(duration: $0) }) { done in
            tint.opacity(done ? 0 : config.flashStrength)
        }
        .id(tick)
    }

    private func shockwave(width: CGFloat) -> some View {
        let tint = color("shockwave")
        let diameter = width * CGFloat(config.shockReach) * 2
        return Burst(duration: config.shockDuration) { done in
            Circle().strokeBorder(tint.opacity(0.85), lineWidth: 2.5)
                .frame(width: diameter, height: diameter)
                .scaleEffect(done ? 1 : 0.1)
                .opacity(done ? 0 : 1)
        }
        .id(tick)
    }

    /// The angle (from straight up, clockwise) the throwing effects go at for this press.
    private func turn(_ id: String) -> CGFloat {
        return EffectDirection.target(config.direction(for: id), random: { CGFloat(unit(tick, 31)) }) ?? 0
    }

    private func confetti(width: CGFloat) -> some View {
        let tint = color("confetti")
        let count = max(1, Int(config.confettiCount.rounded()))
        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                let dx = CGFloat(unit(index, 1) * 2 - 1) * width * 0.9
                let dy = -CGFloat(0.8 + unit(index, 2)) * width
                Burst(duration: config.confettiDuration, curve: { .linear(duration: $0) }) { done in
                    Rectangle()
                        .fill(speckColor("confetti", unit(index, 3), tint))
                        .frame(width: 4 + CGFloat(unit(index, 4)) * 3, height: 2 + CGFloat(unit(index, 5)) * 2)
                        .rotationEffect(.degrees(done ? (unit(index, 6) * 2 - 1) * 460 : 0))
                        .modifier(Ballistic(progress: done ? 1 : 0, dx: dx, dy: dy, gravity: width * 3.2, turn: turn("confetti")))
                        .opacity(done ? 0 : 1)
                }
            }
        }
        .id(tick)
    }

    private func bubbleOffset(_ index: Int, width: CGFloat, done: Bool) -> CGPoint {
        let start = CGFloat(unit(index, 10) - 0.5) * width * 0.7
        let sway = done ? CGFloat(unit(index, 11) - 0.5) * 14 : 0
        return EffectDirection.turn(CGPoint(x: start + sway, y: done ? -CGFloat(config.bubbleRise) : 0), by: turn("bubbles"))
    }

    private func bubbles(width: CGFloat) -> some View {
        let tint = color("bubbles")
        let count = max(1, Int(config.bubbleCount.rounded()))
        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                let size = 5 + CGFloat(unit(index, 7)) * 6
                Burst(duration: 0.7 + unit(index, 8) * 0.4, delay: unit(index, 9) * 0.25,
                      curve: { .easeOut(duration: $0) }) { done in
                    Circle()
                        .strokeBorder(tint.opacity(0.9), lineWidth: 1.5)
                        .background(Circle().fill(tint.opacity(0.18)))
                        .frame(width: size, height: size)
                        .offset(x: bubbleOffset(index, width: width, done: done).x,
                                y: bubbleOffset(index, width: width, done: done).y)
                        .opacity(done ? 0 : 1)
                }
            }
        }
        .id(tick)
    }

    private func ripple(width: CGFloat) -> some View {
        let tint = color("ripple")
        Burst(duration: config.rippleDuration) { done in
            ZStack {
                if config.rippleStyle == "ring" {
                    Circle().strokeBorder(tint.opacity(0.8), lineWidth: 3)
                } else {
                    Circle().fill(tint.opacity(0.55))
                }
            }
            .frame(width: width * 1.4, height: width * 1.4)
            .scaleEffect(done ? CGFloat(config.rippleReach) / 3 : 0.05)
            .opacity(done ? 0 : 1)
        }
        .id(tick)
    }

    private func shine(width: CGFloat, height: CGFloat) -> some View {
        let tint = color("shine")
        let band = width * config.shineWidth
        return Burst(duration: config.shineDuration, curve: { .easeInOut(duration: $0) }) { done in
            LinearGradient(colors: [tint.opacity(0), tint.opacity(0.75), tint.opacity(0)], startPoint: .leading, endPoint: .trailing)
                .frame(width: band, height: height * 1.6)
                .rotationEffect(.degrees(18))
                .offset(x: done ? width : -width)
        }
        .id(tick)
    }

    private func sparks(width: CGFloat) -> some View {
        let tint = color("sparks")
        let count = max(1, Int(config.sparkCount.rounded()))
        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                let angle = 2 * Double.pi * Double(index) / Double(count)
                Burst(duration: config.sparkDuration) { done in
                    Circle()
                        .fill(speckColor("sparks", Double(index) / Double(count), tint))
                        .frame(width: config.sparkSize, height: config.sparkSize)
                        .scaleEffect(done ? 0.3 : 1)
                        .offset(x: done ? cos(angle) * width * config.sparkDistance : 0,
                                y: done ? sin(angle) * width * config.sparkDistance : 0)
                        .opacity(done ? 0 : 1)
                }
            }
        }
        .id(tick)
    }
}
