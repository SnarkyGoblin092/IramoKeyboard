import SwiftUI

/// Key-press vibration: its strength and feel (soft ... rigid), from presets or a pad, and the cursor's ticks.
/// The keyboard maps the feel onto the system's impact styles (Haptics.style(forSharpness:)).
struct HapticsView: View {
    @AppStorage(SettingKey.vibration, store: SharedStore.defaults) private var strength = SettingDefault.vibration
    @AppStorage(SettingKey.hapticSharpness, store: SharedStore.defaults) private var sharpness = SettingDefault.hapticSharpness
    @AppStorage(SettingKey.cursorStartHaptic, store: SharedStore.defaults) private var cursorStart = SettingDefault.cursorStartHaptic
    @AppStorage(SettingKey.cursorTickHaptic, store: SharedStore.defaults) private var cursorTick = SettingDefault.cursorTickHaptic
    @AppStorage(SettingKey.clickSound, store: SharedStore.defaults) private var clicks = SettingDefault.clickSound

    private struct Preset {
        let name: String
        let sharpness: Double
        let strength: Double
    }

    private let presets = [Preset(name: "Soft", sharpness: 0.1, strength: 0.45),
                           Preset(name: "Light", sharpness: 0.3, strength: 0.38),
                           Preset(name: "Medium", sharpness: 0.5, strength: 0.55),
                           Preset(name: "Heavy", sharpness: 0.7, strength: 0.75),
                           Preset(name: "Rigid", sharpness: 0.9, strength: 0.6)]

    /// While the pad is dragged (saved when the finger lifts).
    @State private var dragging: (sharpness: Double, strength: Double)?

    private var shownSharpness: Double { return dragging?.sharpness ?? sharpness }
    private var shownStrength: Double { return dragging?.strength ?? strength }
    private var isOn: Bool { return strength > 0.01 }

    private var feelName: String {
        if !isOn { return "Off" }
        let names = ["Soft", "Light", "Medium", "Heavy", "Rigid"]
        return names[min(4, max(0, Int(shownSharpness * 5)))]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Text("Presets").font(.title3.weight(.bold)).padding(.horizontal, 4)
                HStack(spacing: 8) {
                    ForEach(presets, id: \.name) { preset in
                        let selected = isOn && abs(preset.sharpness - sharpness) < 0.001 && abs(preset.strength - strength) < 0.001
                        PresetCard(title: preset.name, isSelected: selected) {
                            sharpness = preset.sharpness
                            strength = preset.strength
                            Feedback.test(strength: preset.strength, sharpness: preset.sharpness)
                        } picture: {
                            FeelCurve(sharpness: preset.sharpness, strength: 0.7)
                                .stroke(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.secondary), lineWidth: 2.5)
                                .frame(height: 30)
                                .padding(.horizontal, 4)
                        }
                    }
                }

                Text("Feel").font(.title3.weight(.bold)).padding(.horizontal, 4)
                feelPad
                    .padding(16)
                    .glassCard(cornerRadius: GlassMetrics.cardRadius)

                Text("Cursor").font(.title3.weight(.bold)).padding(.horizontal, 4)
                VStack(alignment: .leading, spacing: 18) {
                    GlassToggle(title: "Vibrate when cursor mode starts",
                                subtitle: "One tick when holding the space bar turns it into a trackpad.",
                                isOn: $cursorStart)
                    GlassToggle(title: "Vibrate at each character",
                                subtitle: "A light tick for every character the cursor moves past.",
                                isOn: $cursorTick)
                    Divider()
                    GlassToggle(title: "Key clicks", subtitle: "The system key sound, muted by the silent switch.",
                                isOn: $clicks)
                }
                .padding(16)
                .glassCard(cornerRadius: GlassMetrics.cardRadius)
            }
            .padding(16)
        }
        .background(GlassBackdrop())
        .navigationTitle("Haptics")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(get: { isOn }, set: { on in
                strength = on ? SettingDefault.vibration : 0
                Feedback.tick()
            })) {
                Label("Key press vibration", systemImage: "iphone.radiowaves.left.and.right")
                    .font(.subheadline.weight(.semibold))
            }
            HStack(alignment: .center, spacing: 18) {
                Button {
                    Feedback.test(strength: strength, sharpness: sharpness)
                } label: {
                    VStack(spacing: 6) {
                        Text("a")
                            .font(.system(size: 34, weight: .regular))
                            .foregroundColor(.primary)
                            .frame(width: 66, height: 66)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.primary.opacity(0.10)))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.tint, lineWidth: 1.5))
                        Text("Tap to feel").font(.caption).foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PressableStyle())
                .disabled(!isOn)
                VStack(alignment: .leading, spacing: 4) {
                    Text(feelName).font(.largeTitle.weight(.bold))
                    Text(isOn ? "\(Int((shownStrength * 100).rounded()))%" : "Needs Full Access when on")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            FeelCurve(sharpness: shownSharpness, strength: isOn ? shownStrength : 0.02)
                .stroke(.tint, lineWidth: 3)
                .frame(height: 44)
        }
        .padding(20)
        .glassCard(cornerRadius: GlassMetrics.cardRadius)
    }

    // MARK: Feel pad

    /// Left to right: soft to rigid; bottom to top: 10% to 100% strength.
    private var feelPad: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                VStack {
                    Text("100%")
                    Spacer()
                    Text("10%")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                GeometryReader { geometry in
                    let size = geometry.size
                    let x = CGFloat(shownSharpness) * size.width
                    let y = (1 - CGFloat((shownStrength - 0.1) / 0.9)) * size.height
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                        Path { path in
                            for i in 1..<4 {
                                let gx = size.width * CGFloat(i) / 4
                                path.move(to: CGPoint(x: gx, y: 0))
                                path.addLine(to: CGPoint(x: gx, y: size.height))
                                let gy = size.height * CGFloat(i) / 4
                                path.move(to: CGPoint(x: 0, y: gy))
                                path.addLine(to: CGPoint(x: size.width, y: gy))
                            }
                        }
                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                        Circle()
                            .fill(TintShapeStyle().opacity(0.25))
                            .frame(width: 48, height: 48)
                            .overlay(Circle().fill(.tint).frame(width: 22, height: 22))
                            .overlay(Circle().fill(Color.white).frame(width: 8, height: 8))
                            .position(x: x, y: max(0, min(size.height, y)))
                            .opacity(isOn ? 1 : 0.4)
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let sharp = Double(min(max(value.location.x / max(size.width, 1), 0), 1))
                            let power = 0.1 + 0.9 * Double(1 - min(max(value.location.y / max(size.height, 1), 0), 1))
                            dragging = (sharp, power)
                        }
                        .onEnded { _ in
                            guard let final = dragging else { return }
                            sharpness = (final.sharpness * 20).rounded() / 20
                            strength = (final.strength * 20).rounded() / 20
                            dragging = nil
                            Feedback.test(strength: strength, sharpness: sharpness)
                        })
                }
                .frame(height: 240)
            }
            HStack {
                Text("Soft")
                Spacer()
                Text("Rigid")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.leading, 44)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Feel")
        .accessibilityValue("\(feelName), \(Int((shownStrength * 100).rounded())) percent")
    }
}

/// A bump that is wide and low for a soft feel and a narrow spike for a rigid one; its height is the strength.
private struct FeelCurve: Shape {
    let sharpness: Double
    let strength: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = 0.55 - 0.45 * sharpness        // share of the width the bump takes
        let center = 0.35
        let steps = 60
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let d = (t - center) / max(width / 2.5, 0.02)
            var value = exp(-d * d / 2) * strength
            // A rigid tap rings briefly after the peak.
            if t > center && sharpness > 0.5 { value += sin((t - center) * 60) * 0.06 * sharpness * exp(-(t - center) * 12) }
            let point = CGPoint(x: rect.minX + CGFloat(t) * rect.width,
                                y: rect.maxY - CGFloat(max(0, value)) * rect.height)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}
