import SwiftUI

/// Effects on the keys while they are pressed: a glow that fades in and out, and a ripple of light. The keys in the
/// preview are touchable; the keyboard reads the same settings (Prefs, KeyView.playPressEffects).
struct EffectsView: View {
    @AppStorage(SettingKey.effectGlow, store: SharedStore.defaults) private var glow = SettingDefault.effectGlow
    @AppStorage(SettingKey.effectColor, store: SharedStore.defaults) private var color = SettingDefault.effectColor
    @AppStorage(SettingKey.effectStrength, store: SharedStore.defaults) private var strength = SettingDefault.effectStrength
    @AppStorage(SettingKey.effectSize, store: SharedStore.defaults) private var size = SettingDefault.effectSize
    @AppStorage(SettingKey.effectFadeIn, store: SharedStore.defaults) private var fadeIn = SettingDefault.effectFadeIn
    @AppStorage(SettingKey.effectFadeOut, store: SharedStore.defaults) private var fadeOut = SettingDefault.effectFadeOut
    @AppStorage(SettingKey.effectRipple, store: SharedStore.defaults) private var ripple = SettingDefault.effectRipple
    @AppStorage(SettingKey.effectRippleSize, store: SharedStore.defaults) private var rippleSize = SettingDefault.effectRippleSize

    private let colors = ["accent", "white", "rainbow"]

    private struct Preset {
        let name: String
        let glow: Bool
        let color: String
        let strength: Double
        let size: Double
        let fadeIn: Double
        let fadeOut: Double
        let ripple: Bool
        let rippleSize: Double
    }

    private let presets = [
        Preset(name: tr("Off"), glow: false, color: "accent", strength: 0.6, size: 1, fadeIn: 0.06, fadeOut: 0.4,
               ripple: false, rippleSize: 1.8),
        Preset(name: tr("Glow"), glow: true, color: "accent", strength: 0.6, size: 1, fadeIn: 0.06, fadeOut: 0.4,
               ripple: false, rippleSize: 1.8),
        Preset(name: tr("Neon"), glow: true, color: "accent", strength: 1, size: 1.7, fadeIn: 0.03, fadeOut: 0.8,
               ripple: false, rippleSize: 1.8),
        Preset(name: tr("Ripple"), glow: false, color: "accent", strength: 0.6, size: 1, fadeIn: 0.06, fadeOut: 0.6,
               ripple: true, rippleSize: 2.6),
        Preset(name: tr("Rainbow"), glow: true, color: "rainbow", strength: 0.8, size: 1.3, fadeIn: 0.05, fadeOut: 0.7,
                ripple: true, rippleSize: 2.2),
    ]

    private func same(_ a: Double, _ b: Double) -> Bool { return abs(a - b) < 0.001 }

    private var presetIndex: Int? {
        return presets.firstIndex {
            $0.glow == glow && $0.ripple == ripple && ($0.glow == false || ($0.color == color && same($0.strength, strength)
                && same($0.size, size) && same($0.fadeIn, fadeIn) && same($0.fadeOut, fadeOut)))
                && ($0.ripple == false || same($0.rippleSize, rippleSize))
        }
    }

    private func apply(_ preset: Preset) {
        glow = preset.glow
        ripple = preset.ripple
        if preset.glow {
            color = preset.color
            strength = preset.strength
            size = preset.size
            fadeIn = preset.fadeIn
            fadeOut = preset.fadeOut
        }
        if preset.ripple { rippleSize = preset.rippleSize }
    }

    private var seconds: (Double) -> String { return { String(format: "%.2f s", $0) } }

    var body: some View {
        PinnedPreview(id: "effects", height: 150) {
            EffectsPreview(glow: glow, color: color, strength: strength, size: size, fadeIn: fadeIn,
                           fadeOut: fadeOut, ripple: ripple, rippleSize: rippleSize)
        } content: {
        GlassList {
            Section {
                SegmentedChoice(names: presets.map { $0.name }, selected: presetIndex) { apply(presets[$0]) }
            } header: {
                SectionHeader(tr("Style"), symbol: "wand.and.stars", color: .purple)
            } footer: {
                Text(tr("Touch the keys above to try it. Presets set everything below; change any of it to make your own."))
            }
            .glassRows()

            Section {
                GlassToggle(title: tr("Glow on pressed keys"),
                            subtitle: tr("A light that fades in under your finger and fades out after it lifts."),
                            isOn: $glow)
                Group {
                    SegmentedChoice(title: tr("Colour"), names: [tr("Accent"), tr("White"), tr("Rainbow")],
                                    selected: colors.firstIndex(of: color)) { color = colors[$0] }
                    GlassSlider(title: tr("Strength"), symbol: "dial.medium", value: $strength,
                                range: Settings.effectStrengthRange, step: 0.05) { DeviceMetrics.level($0, in: 0...1) }
                    GlassSlider(title: tr("Spread"), symbol: "circle.dashed", value: $size,
                                range: Settings.effectSizeRange, step: 0.1) { String(format: "%.1f\u{00D7}", $0) }
                    GlassSlider(title: tr("Fade in"), symbol: "sunrise", value: $fadeIn,
                                range: Settings.effectFadeInRange, step: 0.01, format: seconds)
                    GlassSlider(title: tr("Fade out"), symbol: "sunset", value: $fadeOut,
                                range: Settings.effectFadeOutRange, step: 0.05, format: seconds)
                }
                .disabled(!glow)
                .opacity(glow ? 1 : 0.45)
            } header: {
                SectionHeader(tr("Glow"), symbol: "light.max", color: .orange)
            } footer: {
                Text(tr("Rainbow gives every press a new colour."))
            }
            .glassRows()

            Section {
                GlassToggle(title: tr("Ripple"),
                            subtitle: tr("A disc of light spreads from the middle of the key and fades away."),
                            isOn: $ripple)
                GlassSlider(title: tr("Reach"), symbol: "dot.circle.and.hand.point.up.left.fill", value: $rippleSize,
                            range: Settings.effectRippleSizeRange, step: 0.1) { String(format: "%.1f\u{00D7}", $0) }
                    .disabled(!ripple)
                    .opacity(ripple ? 1 : 0.45)
            } header: {
                SectionHeader(tr("Ripple"), symbol: "circle.hexagongrid.fill", color: .teal)
            } footer: {
                Text(tr("The ripple fades out as slowly as the glow does."))
            }
            .glassRows()
        }
        .scrollContentBackground(.hidden)
        }
        .navigationTitle(tr("Effects"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A few touchable keys that play the effects as the keyboard does.
private struct EffectsPreview: View {
    let glow: Bool
    let color: String
    let strength: Double
    let size: Double
    let fadeIn: Double
    let fadeOut: Double
    let ripple: Bool
    let rippleSize: Double

    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @State private var hue = 0.0
    /// The keys being touched, and the colour each one's glow has.
    @State private var down: [String: Color] = [:]
    /// The colour a key's glow fades out in after it lifts.
    @State private var tints: [String: Color] = [:]

    private let letters = Array("QWERTY").map { String($0) }

    var body: some View {
        let accent = Color.currentAccent(name: accentName, hex: accentHex)
        // Two rows of the same keys: the glows underneath, the keys on top, so a glow never covers another key.
        ZStack {
            HStack(spacing: 8) {
                ForEach(letters, id: \.self) { letter in
                    let tint = tints[letter] ?? .clear
                    let lit = glow && down[letter] != nil
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(lit ? strength : 0))
                        .shadow(color: tint.opacity(lit ? strength : 0), radius: 9 * size)
                        .frame(height: 54)
                }
            }
            HStack(spacing: 8) {
                ForEach(letters, id: \.self) { letter in
                    EffectKey(letter: letter, tint: tints[letter] ?? .clear, lit: glow && down[letter] != nil,
                              ripple: ripple, rippleSize: rippleSize, fadeIn: fadeIn, fadeOut: fadeOut,
                              press: { press(letter, accent: accent) }, release: { release(letter) })
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }

    private func press(_ letter: String, accent: Color) {
        guard down[letter] == nil else { return }
        switch color {
        case "white":
            tints[letter] = .white
        case "rainbow":
            hue = (hue + 0.11).truncatingRemainder(dividingBy: 1)
            tints[letter] = Color(hue: hue, saturation: 0.75, brightness: 1)
        default:
            tints[letter] = accent
        }
        withAnimation(.easeOut(duration: max(fadeIn, 0.001))) { down[letter] = tints[letter] }
    }

    private func release(_ letter: String) {
        withAnimation(.easeIn(duration: max(fadeOut, 0.001))) { down[letter] = nil }
    }
}

private struct EffectKey: View {
    let letter: String
    let tint: Color
    let lit: Bool
    let ripple: Bool
    let rippleSize: Double
    let fadeIn: Double
    let fadeOut: Double
    let press: () -> Void
    let release: () -> Void

    @State private var pressed = false
    @State private var burst = 0
    @State private var burstOn = false

    private var shape: RoundedRectangle { return RoundedRectangle(cornerRadius: 10, style: .continuous) }

    var body: some View {
        ZStack {
            // The ripple stays inside the key's shape.
            shape.fill(Color(.secondarySystemGroupedBackground).opacity(lit ? 0.55 : 1))
            GeometryReader { geometry in
                Circle()
                    .fill(tint.opacity(0.55))
                    .frame(width: geometry.size.width * 1.4, height: geometry.size.width * 1.4)
                    .scaleEffect(burstOn ? rippleSize / 3 : 0.05)
                    .opacity(burst == 0 || burstOn ? 0 : 1)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .id(burst)
            }
            .clipShape(shape)
            Text(letter).font(.title3.weight(.medium))
        }
        .frame(height: 54)
        .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 1))
        .contentShape(shape)
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !pressed else { return }
                pressed = true
                press()
                if ripple {
                    burst += 1   // a new disc, starting small
                    burstOn = false
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: max(fadeOut, 0.25))) { burstOn = true }
                    }
                }
            }
            .onEnded { _ in
                pressed = false
                release()
            })
    }
}
