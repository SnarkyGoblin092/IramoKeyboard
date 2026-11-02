import SwiftUI

/// Effects on the keys while they are pressed: a glow, a lit outline, a ripple, a shine, sparks, a pop of the label,
/// an echo of it and a wave over the neighbouring keys, each with its own settings, and a glow on the swipe trail.
/// The keyboard above is touchable; the keyboard reads the same settings (Prefs.effects, KeyView).
struct EffectsView: View {
    @AppStorage(SettingKey.effects, store: SharedStore.defaults) private var json = SettingDefault.effects

    private let colorModes = ["accent", "white", "rainbow", "custom"]

    private var config: EffectsConfig { return EffectsConfig.decode(json) }

    private func bind<Value>(_ keyPath: WritableKeyPath<EffectsConfig, Value>) -> Binding<Value> {
        return Binding(get: { config[keyPath: keyPath] }, set: { value in
            var next = config
            next[keyPath: keyPath] = value
            json = next.encoded()
        })
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
            c.colorMode = "rainbow"
            c.confetti = true; c.confettiCount = 18
            c.squish = true
            return c
        },
        Preset(name: tr("Bubbles")) {
            var c = EffectsConfig()
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
            c.hearts = true; c.heartCount = 8
            c.heartbeat = true
            c.glow = true; c.glowStrength = 0.5
            return c
        },
        Preset(name: tr("Winter")) {
            var c = EffectsConfig()
            c.colorMode = "white"
            c.snow = true; c.snowCount = 14
            c.sweep = true
            return c
        },
        Preset(name: tr("Storm")) {
            var c = EffectsConfig()
            c.rain = true; c.rainCount = 12
            c.lightning = true
            c.shake = true
            return c
        },
        Preset(name: tr("Party")) {
            var c = EffectsConfig()
            c.colorMode = "rainbow"
            c.fireworks = true
            c.stars = true
            c.confetti = true
            return c
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
            c.orbit = true
            c.spiral = true
            c.beam = true
            return c
        },
        Preset(name: tr("Bounce")) {
            var c = EffectsConfig()
            c.pop = true; c.popScale = 1.5
            c.echo = true
            return c
        },
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
                Picker(selection: Binding(get: { presetIndex ?? -1 }, set: { index in
                    guard presets.indices.contains(index) else { return }
                    Feedback.choose()
                    json = presets[index].make().encoded()
                })) {
                    if presetIndex == nil { Text(tr("Your own mix")).tag(-1) }
                    ForEach(presets.indices, id: \.self) { Text(presets[$0].name).tag($0) }
                } label: {
                    Label(tr("Style"), systemImage: "wand.and.stars")
                }
                .pickerStyle(.menu)
            } header: {
                SectionHeader(tr("Presets"), symbol: "wand.and.stars", color: .purple)
            } footer: {
                Text(tr("Touch the keyboard above to try it. A preset sets everything; change any of it below to make your own."))
            }
            .glassRows()

            Section {
                SegmentedChoice(names: [tr("Accent"), tr("White"), tr("Rainbow"), tr("Custom")],
                                selected: colorModes.firstIndex(of: config.colorMode)) { bind(\.colorMode).wrappedValue = colorModes[$0] }
                if config.colorMode == "custom" {
                    ColorPicker(tr("Colour"), selection: Binding(get: { Color(config.customColor) }, set: { color in
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

            effect(tr("Glow"), "light.max", .orange, on: bind(\.glow),
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

            effect(tr("Outline light"), "square.dashed", .blue, on: bind(\.border),
                   note: tr("A line round the key lights up and fades away.")) {
                GlassSlider(title: tr("Width"), symbol: "lineweight", value: bind(\.borderWidth),
                            range: EffectsConfig.borderWidthRange, step: 0.1) { String(format: "%.1f pt", $0) }
                GlassSlider(title: tr("Fade out"), symbol: "sunset", value: bind(\.borderFade),
                            range: EffectsConfig.borderFadeRange, step: 0.05, format: seconds)
            }

            effect(tr("Ripple"), "circle.hexagongrid.fill", .teal, on: bind(\.ripple),
                   note: tr("Light spreads from the middle of the key, inside its shape, and fades away.")) {
                SegmentedChoice(title: tr("Shape"), names: [tr("Disc"), tr("Ring")],
                                selected: config.rippleStyle == "ring" ? 1 : 0) { bind(\.rippleStyle).wrappedValue = $0 == 1 ? "ring" : "disc" }
                GlassSlider(title: tr("Reach"), symbol: "arrow.up.left.and.arrow.down.right", value: bind(\.rippleReach),
                            range: EffectsConfig.rippleReachRange, step: 0.1, format: times)
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.rippleDuration),
                            range: EffectsConfig.rippleDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Shine"), "sun.max.fill", .yellow, on: bind(\.shine),
                   note: tr("A slanted band of light sweeps across the key.")) {
                GlassSlider(title: tr("Band width"), symbol: "arrow.left.and.right", value: bind(\.shineWidth),
                            range: EffectsConfig.shineWidthRange, step: 0.05) { String(format: "%.0f%%", $0 * 100) }
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.shineDuration),
                            range: EffectsConfig.shineDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Sparks"), "sparkles", .pink, on: bind(\.sparks),
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

            effect(tr("Pop"), "arrow.up.left.and.down.right.magnifyingglass", .green, on: bind(\.pop),
                   note: tr("The label swells (or shrinks) and springs back.")) {
                GlassSlider(title: tr("Size"), symbol: "textformat.size", value: bind(\.popScale),
                            range: EffectsConfig.popScaleRange, step: 0.05, format: times)
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.popDuration),
                            range: EffectsConfig.popDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Echo"), "text.append", .indigo, on: bind(\.echo),
                   note: tr("A copy of the label floats up out of the key and fades.")) {
                GlassSlider(title: tr("Rise"), symbol: "arrow.up", value: bind(\.echoRise),
                            range: EffectsConfig.echoRiseRange, step: 1) { "\(Int($0.rounded())) pt" }
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.echoDuration),
                            range: EffectsConfig.echoDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Wave"), "dot.radiowaves.left.and.right", .cyan, on: bind(\.wave),
                   note: tr("The keys around the pressed one light up in turn, the farther ones a moment later.")) {
                GlassSlider(title: tr("Reach"), symbol: "arrow.up.left.and.arrow.down.right", value: bind(\.waveReach),
                            range: EffectsConfig.waveReachRange, step: 0.1) { String(format: "%.1f keys", $0) }
                GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: bind(\.waveStrength),
                            range: EffectsConfig.waveStrengthRange, step: 0.05) { DeviceMetrics.level($0, in: 0...1) }
                GlassSlider(title: tr("Speed"), symbol: "speedometer", value: bind(\.waveSpeed),
                            range: EffectsConfig.waveSpeedRange, step: 0.01) { String(format: "%.0f ms/key", $0 * 1000) }
            }

            effect(tr("Shockwave"), "dot.radiowaves.right", .mint, on: bind(\.shockwave),
                   note: tr("A ring of light spreads far out over the keys around the one you press.")) {
                GlassSlider(title: tr("Reach"), symbol: "arrow.up.left.and.arrow.down.right", value: bind(\.shockReach),
                            range: EffectsConfig.shockReachRange, step: 0.1) { String(format: "%.1f keys", $0) }
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.shockDuration),
                            range: EffectsConfig.shockDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Confetti"), "gift.fill", .orange, on: bind(\.confetti),
                   note: tr("Little pieces of paper are thrown up out of the key and tumble down.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.confettiCount),
                            range: EffectsConfig.confettiCountRange, step: 1) { "\(Int($0.rounded()))" }
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.confettiDuration),
                            range: EffectsConfig.confettiDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Bubbles"), "circle.grid.2x2.fill", .cyan, on: bind(\.bubbles),
                   note: tr("Bubbles float up from the key, swaying as they go.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.bubbleCount),
                            range: EffectsConfig.bubbleCountRange, step: 1) { "\(Int($0.rounded()))" }
                GlassSlider(title: tr("Rise"), symbol: "arrow.up", value: bind(\.bubbleRise),
                            range: EffectsConfig.bubbleRiseRange, step: 5) { "\(Int($0.rounded())) pt" }
            }

            effect(tr("Squish"), "arrow.down.right.and.arrow.up.left", .green, on: bind(\.squish),
                   note: tr("The key squashes under your finger and springs back.")) {
                GlassSlider(title: tr("Depth"), symbol: "arrow.down.to.line", value: bind(\.squishDepth),
                            range: EffectsConfig.squishDepthRange, step: 0.01) { String(format: "%.0f%%", (1 - $0) * 100) }
            }

            effect(tr("Flash"), "bolt.fill", .yellow, on: bind(\.flash),
                   note: tr("The key lights up in the effect colour for a moment.")) {
                GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: bind(\.flashStrength),
                            range: EffectsConfig.flashStrengthRange, step: 0.05) { DeviceMetrics.level($0, in: 0...1) }
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.flashDuration),
                            range: EffectsConfig.flashDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Jelly"), "waveform.path", .purple, on: bind(\.jelly),
                   note: tr("The key wobbles like jelly, the swings getting smaller.")) {
                GlassSlider(title: tr("Swing"), symbol: "arrow.left.and.right", value: bind(\.jellyAngle),
                            range: EffectsConfig.jellyAngleRange, step: 1) { "\(Int($0.rounded()))\u{00B0}" }
            }

            effect(tr("Hearts"), "heart.fill", .pink, on: bind(\.hearts),
                   note: tr("Little hearts float up from the key.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.heartCount),
                            range: EffectsConfig.heartCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Stars"), "star.fill", .yellow, on: bind(\.stars),
                   note: tr("Stars burst out of the key and fade.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.starCount),
                            range: EffectsConfig.starCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Snow"), "snowflake", .cyan, on: bind(\.snow),
                   note: tr("Snowflakes drift down past the key.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.snowCount),
                            range: EffectsConfig.snowCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Notes"), "music.note", .purple, on: bind(\.notes),
                   note: tr("Musical notes drift up and to the side.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.noteCount),
                            range: EffectsConfig.noteCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Fireworks"), "sparkle", .orange, on: bind(\.fireworks),
                   note: tr("Streaks burst out of the key and fall like fireworks.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.fireworkCount),
                            range: EffectsConfig.fireworkCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Starburst"), "sun.max", .yellow, on: bind(\.starburst),
                   note: tr("Thin rays shoot out of the key in every direction.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.rayCount),
                            range: EffectsConfig.rayCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Rain"), "cloud.rain.fill", .blue, on: bind(\.rain),
                   note: tr("Drops of rain fall past the key.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.rainCount),
                            range: EffectsConfig.rainCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Embers"), "flame.fill", .red, on: bind(\.embers),
                   note: tr("Glowing embers rise and flicker out.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.emberCount),
                            range: EffectsConfig.emberCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Smoke"), "smoke.fill", .gray, on: bind(\.smoke),
                   note: tr("Soft puffs of smoke rise from the key and grow.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.smokeCount),
                            range: EffectsConfig.smokeCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Lightning"), "bolt.circle.fill", .indigo, on: bind(\.lightning),
                   note: tr("A bolt of lightning strikes up from the key.")) {
                GlassSlider(title: tr("Length"), symbol: "arrow.up.and.down", value: bind(\.lightningLength),
                            range: EffectsConfig.lightningLengthRange, step: 0.1) { String(format: "%.1f keys", $0) }
            }

            effect(tr("Orbit"), "atom", .teal, on: bind(\.orbit),
                   note: tr("Little lights circle around the key.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.orbitCount),
                            range: EffectsConfig.orbitCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Spiral"), "tornado", .mint, on: bind(\.spiral),
                   note: tr("Specks spiral outwards from the key.")) {
                GlassSlider(title: tr("Count"), symbol: "number", value: bind(\.spiralCount),
                            range: EffectsConfig.spiralCountRange, step: 1) { "\(Int($0.rounded()))" }
            }

            effect(tr("Heartbeat"), "heart.circle.fill", .pink, on: bind(\.heartbeat),
                   note: tr("The key pulses twice like a heartbeat.")) {
                GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: bind(\.heartbeatStrength),
                            range: EffectsConfig.heartbeatStrengthRange, step: 0.01) { String(format: "+%.0f%%", ($0 - 1) * 100) }
            }

            effect(tr("Flip"), "rectangle.2.swap", .blue, on: bind(\.flip),
                   note: tr("The key flips over like a card.")) {
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.flipDuration),
                            range: EffectsConfig.flipDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Shake"), "iphone.radiowaves.left.and.right", .orange, on: bind(\.shake),
                   note: tr("The key shakes from side to side.")) {
                GlassSlider(title: tr("Distance"), symbol: "arrow.left.and.right", value: bind(\.shakeDistance),
                            range: EffectsConfig.shakeDistanceRange, step: 1) { "\(Int($0.rounded())) pt" }
            }

            effect(tr("Drop"), "arrow.down.circle.fill", .green, on: bind(\.drop),
                   note: tr("The key sinks and bounces back.")) {
                GlassSlider(title: tr("Depth"), symbol: "arrow.down.to.line", value: bind(\.dropDepth),
                            range: EffectsConfig.dropDepthRange, step: 1) { "\(Int($0.rounded())) pt" }
            }

            effect(tr("Glitch"), "waveform.path.ecg", .red, on: bind(\.glitch),
                   note: tr("The key glitches with flickering colours.")) {
                GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: bind(\.glitchStrength),
                            range: EffectsConfig.glitchStrengthRange, step: 0.05) { DeviceMetrics.level($0, in: 0...1) }
            }

            effect(tr("Underline"), "underline", .cyan, on: bind(\.underline),
                   note: tr("A line grows along the bottom of the key and fades.")) {
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.underlineDuration),
                            range: EffectsConfig.underlineDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Neon sweep"), "arrow.triangle.2.circlepath", .teal, on: bind(\.sweep),
                   note: tr("A light runs round the key's outline.")) {
                GlassSlider(title: tr("Duration"), symbol: "timer", value: bind(\.sweepDuration),
                            range: EffectsConfig.sweepDurationRange, step: 0.05, format: seconds)
            }

            effect(tr("Beam"), "rays", .yellow, on: bind(\.beam),
                   note: tr("A beam of light rises from the key.")) {
                GlassSlider(title: tr("Height"), symbol: "arrow.up.to.line", value: bind(\.beamHeight),
                            range: EffectsConfig.beamHeightRange, step: 0.1) { String(format: "%.1f keys", $0) }
            }

            effect(tr("Swipe trail"), "scribble", .red, on: bind(\.trail),
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

    /// One effect: a switch with a line of explanation, and its settings underneath while it is on.
    private func effect<Settings: View>(_ title: String, _ symbol: String, _ color: Color, on: Binding<Bool>, note: String,
                                        @ViewBuilder settings: () -> Settings) -> some View {
        Section {
            GlassToggle(title: title, subtitle: note, isOn: on)
            if on.wrappedValue { settings() }
        } header: {
            SectionHeader(title, symbol: symbol, color: color)
        }
        .glassRows()
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
    @State private var up = false
    @State private var down = false

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(tint.opacity(up && !down ? strength : 0))
            .shadow(color: tint.opacity(up && !down ? strength : 0), radius: 9)
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

    var animatableData: CGFloat {
        get { return progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = progress
        return ProjectionTransform(CGAffineTransform(translationX: dx * t, y: dy * t + gravity * t * t / 2))
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
    @State private var ticks: [String: Int] = [:]
    @State private var waves: [String: PulseRequest] = [:]
    @State private var poses: [String: EffectPose] = [:]

    struct PulseRequest {
        let tick: Int
        let delay: Double
        let strength: Double
        let tint: Color
    }

    var body: some View {
        content()
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
                if let frame = frames[id], (ticks[id] ?? 0) > 0 {
                    EffectsKeyFX(config: config, frame: frame, tint: tints[id] ?? .clear, tick: ticks[id] ?? 0)
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
                .shadow(color: tint.opacity(lit ? config.glowStrength : 0), radius: 9 * config.glowSpread)
            if let wave = wave {
                Pulse(strength: wave.strength, fade: max(config.glowFadeOut, 0.3), delay: wave.delay, tint: wave.tint)
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

    private func press(_ touch: Int, at point: CGPoint) {
        guard let id = key(at: point), let frame = frames[id] else { return }
        touchKeys[touch] = id
        guard down[id] == nil else { return }
        let tint: Color
        switch config.colorMode {
        case "white":
            tint = .white
        case "custom":
            tint = Color(config.customColor)
        case "rainbow":
            hue = (hue + 0.11).truncatingRemainder(dividingBy: 1)
            tint = Color(hue: hue, saturation: 0.75, brightness: 1)
        default:
            tint = Color.currentAccent(name: accentName, hex: accentHex)
        }
        tints[id] = tint
        counter += 1
        ticks[id] = counter
        withAnimation(.easeOut(duration: max(config.glowFadeIn, 0.001))) { down[id] = tint }
        if config.squish { squish(id) }
        if config.jelly { jelly(id) }
        if config.heartbeat {
            let beat = CGFloat(config.heartbeatStrength)
            play(id, [beat, 1, beat, 1], every: 0.12) { pose, value in pose.scale = value }
        }
        if config.shake {
            let d = CGFloat(config.shakeDistance)
            play(id, [-d, d, -d * 0.7, d * 0.5, -d * 0.2, 0], every: 0.05) { pose, value in pose.offsetX = value }
        }
        if config.drop {
            let d = CGFloat(config.dropDepth)
            play(id, [d, -d * 0.35, d * 0.12, 0], every: 0.09) { pose, value in pose.offsetY = value }
        }
        if config.glitch {
            let d = CGFloat(config.glitchStrength) * 6
            play(id, [-d, d * 0.8, -d * 0.5, d * 0.6, 0], every: 0.045) { pose, value in pose.offsetX = value }
        }
        if config.flip { flip(id) }
        if config.wave {
            let unit = max(frames.values.map { $0.rect.width }.min() ?? 40, 1)
            for (other, otherFrame) in frames where other != id {
                let apart = hypot(otherFrame.rect.midX - frame.rect.midX, otherFrame.rect.midY - frame.rect.midY) / unit
                guard apart <= config.waveReach else { continue }
                waves[other] = PulseRequest(tick: counter, delay: apart * config.waveSpeed,
                                            strength: config.waveStrength * (1 - apart / (config.waveReach + 0.5)), tint: tint)
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
    let tint: Color
    let tick: Int

    private var shape: RoundedRectangle { return RoundedRectangle(cornerRadius: frame.radius, style: .continuous) }

    var body: some View {
        let width = frame.rect.width
        let height = frame.rect.height
        ZStack {
            // Effects that stay inside the key's shape.
            ZStack {
                if config.ripple { ripple(width: width) }
                if config.shine { shine(width: width, height: height) }
                if config.flash { flash() }
                if config.underline { underline(width: width, height: height) }
                if config.glitch { glitchSlabs() }
            }
            .frame(width: width, height: height)
            .clipShape(shape)
            if config.border {
                Burst(duration: config.borderFade, curve: { .easeIn(duration: $0) }) { done in
                    shape.strokeBorder(tint, lineWidth: config.borderWidth).opacity(done ? 0 : 1)
                }
                .id(tick)
                .frame(width: width, height: height)
            }
            if config.echo && !frame.label.isEmpty {
                Burst(duration: config.echoDuration) { done in
                    Text(frame.label).font(.title3.weight(.medium))
                        .offset(y: done ? -config.echoRise : 0)
                        .opacity(done ? 0 : 0.85)
                }
                .id(tick)
            }
            if config.pop && !frame.label.isEmpty {
                Burst(duration: config.popDuration, curve: { _ in .interpolatingSpring(stiffness: 260, damping: 8) }) { done in
                    Text(frame.label).font(.title3.weight(.medium)).scaleEffect(done ? 1 : config.popScale)
                }
                .id(tick)
            }
            if config.sparks { sparks(width: width) }
            if config.shockwave { shockwave(width: width) }
            if config.confetti { confetti(width: width) }
            if config.bubbles { bubbles(width: width) }
            if config.sweep {
                Burst(duration: config.sweepDuration, curve: { .linear(duration: $0) }) { done in
                    shape.trim(from: done ? 0.85 : 0, to: done ? 1 : 0.15)
                        .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .shadow(color: tint, radius: 4)
                        .opacity(done ? 0 : 1)
                }
                .id(tick)
                .frame(width: width, height: height)
            }
            if config.lightning { lightning(width: width, height: height) }
            if config.beam { beam(width: width) }
            particles
        }
        .frame(width: width, height: height)
        .position(x: frame.rect.midX, y: frame.rect.midY)
    }

    private func underline(width: CGFloat, height: CGFloat) -> some View {
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

    private func lightning(width: CGFloat, height: CGFloat) -> some View {
        let length = width * CGFloat(config.lightningLength)
        let segments = 7
        let salt = tick * 7
        return Burst(duration: 0.32, curve: { .easeIn(duration: $0) }) { done in
            Path { path in
                path.move(to: CGPoint(x: width / 2, y: height / 2))
                for step in 1...segments {
                    let sideways: CGFloat = step == segments ? 0 : (CGFloat(unit(step + salt, 21)) - 0.5) * width * 0.56
                    path.addLine(to: CGPoint(x: width / 2 + sideways, y: height / 2 - length * CGFloat(step) / CGFloat(segments)))
                }
            }
            .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .shadow(color: tint, radius: 5)
            .opacity(done ? 0 : 1)
        }
        .id(tick)
    }

    private func beam(width: CGFloat) -> some View {
        let reach = width * CGFloat(config.beamHeight)
        return Burst(duration: 0.5) { done in
            Rectangle()
                .fill(LinearGradient(colors: [tint.opacity(0.8), tint.opacity(0)], startPoint: .bottom, endPoint: .top))
                .frame(width: width * 0.5, height: reach)
                .scaleEffect(x: 1, y: done ? 1 : 0.15, anchor: .bottom)
                .opacity(done ? 0 : 1)
                .offset(y: -reach / 2)
        }
        .id(tick)
    }

    // The particle effects (EffectParticles), as the keyboard plays them.

    private var particles: some View {
        let specs = EffectParticles.make(config, keySize: frame.rect.size) { index, salt in CGFloat(unit(index + tick * 13, Double(salt))) }
        return ZStack {
            ForEach(0..<specs.count, id: \.self) { index in
                Later(delay: specs[index].delay) { particle(specs[index]) }
            }
        }
        .id(tick)
    }

    private func particle(_ spec: EffectParticle) -> some View {
        let color: Color = spec.hue.map { Color(hue: Double($0), saturation: 0.7, brightness: 1) } ?? tint
        return Burst(duration: spec.duration, curve: { .linear(duration: $0) }) { done in
            particleShape(spec, color: color)
                .rotationEffect(.radians(done ? Double(spec.spin) : 0))
                .scaleEffect(done ? spec.scaleTo : spec.scaleFrom)
                .modifier(Along(progress: done ? 1 : 0, path: spec.path))
                .opacity(done ? 0 : Double(spec.peak))
        }
    }

    @ViewBuilder private func particleShape(_ spec: EffectParticle, color: Color) -> some View {
        switch spec.shape {
        case .glyph(let text):
            Text(text).font(.system(size: spec.size)).foregroundColor(color)
        case .dot:
            Circle().fill(color).frame(width: spec.size, height: spec.size)
        case .streak(let angle):
            Capsule().fill(color).frame(width: spec.size, height: 2).rotationEffect(.radians(Double(angle)))
        case .drop:
            Capsule().fill(color).frame(width: 1.5, height: spec.size)
        case .soft:
            Circle().fill(color.opacity(0.35)).frame(width: spec.size, height: spec.size).blur(radius: 3)
        case .ember:
            Circle().fill(color).frame(width: spec.size, height: spec.size).shadow(color: color, radius: 3)
        }
    }

    private func flash() -> some View {
        return Burst(duration: config.flashDuration, curve: { .easeIn(duration: $0) }) { done in
            tint.opacity(done ? 0 : config.flashStrength)
        }
        .id(tick)
    }

    private func shockwave(width: CGFloat) -> some View {
        let diameter = width * CGFloat(config.shockReach) * 2
        return Burst(duration: config.shockDuration) { done in
            Circle().strokeBorder(tint.opacity(0.85), lineWidth: 2.5)
                .frame(width: diameter, height: diameter)
                .scaleEffect(done ? 1 : 0.1)
                .opacity(done ? 0 : 1)
        }
        .id(tick)
    }

    private func confetti(width: CGFloat) -> some View {
        let count = max(1, Int(config.confettiCount.rounded()))
        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                let dx = CGFloat(unit(index, 1) * 2 - 1) * width * 0.9
                let dy = -CGFloat(0.8 + unit(index, 2)) * width
                Burst(duration: config.confettiDuration, curve: { .linear(duration: $0) }) { done in
                    Rectangle()
                        .fill(config.colorMode == "rainbow" ? Color(hue: unit(index, 3), saturation: 0.7, brightness: 1) : tint)
                        .frame(width: 4 + CGFloat(unit(index, 4)) * 3, height: 2 + CGFloat(unit(index, 5)) * 2)
                        .rotationEffect(.degrees(done ? (unit(index, 6) * 2 - 1) * 460 : 0))
                        .modifier(Ballistic(progress: done ? 1 : 0, dx: dx, dy: dy, gravity: width * 3.2))
                        .opacity(done ? 0 : 1)
                }
            }
        }
        .id(tick)
    }

    private func bubbles(width: CGFloat) -> some View {
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
                        .offset(x: CGFloat(unit(index, 10) - 0.5) * width * 0.7 + (done ? CGFloat(unit(index, 11) - 0.5) * 14 : 0),
                                y: done ? -CGFloat(config.bubbleRise) : 0)
                        .opacity(done ? 0 : 1)
                }
            }
        }
        .id(tick)
    }

    private func ripple(width: CGFloat) -> some View {
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
        let count = max(1, Int(config.sparkCount.rounded()))
        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                let angle = 2 * Double.pi * Double(index) / Double(count)
                Burst(duration: config.sparkDuration) { done in
                    Circle()
                        .fill(config.colorMode == "rainbow" ? Color(hue: Double(index) / Double(count), saturation: 0.7, brightness: 1) : tint)
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
