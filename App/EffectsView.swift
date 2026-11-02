import SwiftUI

/// Effects on the keys while they are pressed: a glow, a lit outline, a ripple, a shine, sparks, a pop of the label,
/// an echo of it and a wave over the neighbouring keys, each with its own settings, and a glow on the swipe trail.
/// The keys in the preview are touchable; the keyboard reads the same settings (Prefs.effects, KeyView).
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
        PinnedPreview(id: "effects", height: 170) {
            EffectsPreview(config: config)
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
                Text(tr("Touch the keys above to try it. A preset sets everything; change any of it below to make your own."))
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
private struct Burst<Content: View>: View {
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
private struct Pulse: View {
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

/// A few touchable keys that play the effects as the keyboard does.
private struct EffectsPreview: View {
    let config: EffectsConfig

    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @State private var hue = 0.0
    /// The keys being touched, and the colour of each one's press.
    @State private var down: [Int: Color] = [:]
    @State private var tints: [Int: Color] = [:]
    /// A counter per key that restarts its one-shot effects; and the order keys were pressed in (the latest is on top).
    @State private var ticks: [Int: Int] = [:]
    @State private var order: [Int: Int] = [:]
    @State private var waves: [Int: (tick: Int, delay: Double, strength: Double)] = [:]
    @State private var counter = 0

    private let letters = Array("QWERTY").map { String($0) }

    var body: some View {
        let accent = Color.currentAccent(name: accentName, hex: accentHex)
        // Two rows of the same keys: the lights underneath, the keys on top, so a glow never covers another key.
        ZStack {
            HStack(spacing: 8) {
                ForEach(letters.indices, id: \.self) { index in
                    let tint = tints[index] ?? .clear
                    let lit = config.glow && down[index] != nil
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tint.opacity(lit ? config.glowStrength : 0))
                            .shadow(color: tint.opacity(lit ? config.glowStrength : 0), radius: 9 * config.glowSpread)
                        if let wave = waves[index] {
                            Pulse(strength: wave.strength, fade: max(config.glowFadeOut, 0.3), delay: wave.delay, tint: tint)
                                .id(wave.tick)
                        }
                    }
                    .frame(height: 54)
                }
            }
            HStack(spacing: 8) {
                ForEach(letters.indices, id: \.self) { index in
                    PreviewKey(letter: letters[index], config: config, tint: tints[index] ?? .clear,
                               lit: config.glow && down[index] != nil, tick: ticks[index] ?? 0,
                               press: { press(index, accent: accent) }, release: { release(index) })
                        .zIndex(Double(order[index] ?? 0))
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }

    private func press(_ index: Int, accent: Color) {
        guard down[index] == nil else { return }
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
            tint = accent
        }
        tints[index] = tint
        counter += 1
        order[index] = counter
        ticks[index] = counter
        withAnimation(.easeOut(duration: max(config.glowFadeIn, 0.001))) { down[index] = tint }
        if config.wave {
            for other in letters.indices where other != index {
                let distance = Double(abs(other - index))
                guard distance <= config.waveReach else { continue }
                tints[other] = tint
                waves[other] = (counter, distance * config.waveSpeed,
                                config.waveStrength * (1 - distance / (config.waveReach + 0.5)))
            }
        }
    }

    private func release(_ index: Int) {
        withAnimation(.easeIn(duration: max(config.glowFadeOut, 0.001))) { down[index] = nil }
    }
}

private struct PreviewKey: View {
    let letter: String
    let config: EffectsConfig
    let tint: Color
    let lit: Bool
    let tick: Int
    let press: () -> Void
    let release: () -> Void

    @State private var pressed = false

    private var shape: RoundedRectangle { return RoundedRectangle(cornerRadius: 10, style: .continuous) }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack {
                shape.fill(Color(.secondarySystemGroupedBackground).opacity(lit ? 0.55 : 1))
                // Effects that stay inside the key's shape.
                ZStack {
                    if tick > 0 && config.ripple { ripple(width: width) }
                    if tick > 0 && config.shine { shine(width: width, height: geometry.size.height) }
                }
                .clipShape(shape)
                if tick > 0 && config.border {
                    Burst(duration: config.borderFade, curve: { .easeIn(duration: $0) }) { done in
                        shape.strokeBorder(tint, lineWidth: config.borderWidth).opacity(done ? 0 : 1)
                    }
                    .id(tick)
                }
                if tick > 0 && config.echo {
                    Burst(duration: config.echoDuration) { done in
                        Text(letter).font(.title3.weight(.medium))
                            .offset(y: done ? -config.echoRise : 0)
                            .opacity(done ? 0 : 0.85)
                    }
                    .id(tick)
                }
                if tick > 0 && config.sparks { sparks(width: width) }
                label
            }
            .frame(width: width, height: geometry.size.height)
            .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 1))
            .contentShape(shape)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pressed else { return }
                    pressed = true
                    press()
                }
                .onEnded { _ in
                    pressed = false
                    release()
                })
        }
        .frame(height: 54)
    }

    @ViewBuilder private var label: some View {
        if tick > 0 && config.pop {
            Burst(duration: config.popDuration, curve: { _ in .interpolatingSpring(stiffness: 260, damping: 8) }) { done in
                Text(letter).font(.title3.weight(.medium)).scaleEffect(done ? 1 : config.popScale)
            }
            .id(tick)
        } else {
            Text(letter).font(.title3.weight(.medium))
        }
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
        .allowsHitTesting(false)
    }
}
