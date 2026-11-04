import SwiftUI

/// The editor of a theme (Native, Transparent, Liquid Glass): its corners and key style, solidity, outline and glow. Every change is saved at once as that theme's own style (SystemEdits); Reset puts the
/// theme back as it was. The keyboard (Theme.system) and the previews (ThemeLook.system) read the same style.
struct SystemThemeSections: View {
    let theme: ThemeDefinition
    @AppStorage(SettingKey.systemEdits, store: SharedStore.defaults) private var systemEdits = SettingDefault.systemEdits

    private let corners: [Double] = [0, 0.12, 0.26, 1]
    private let surfaces = ["auto", "flat", "sheen", "raised"]
    private let borders = ["auto", "none", "thin", "bold", "accent"]
    private let glows = ["off", "soft", "strong"]

    private func same(_ a: Double, _ b: Double) -> Bool { return abs(a - b) < 0.001 }

    /// The style being edited: the theme's own, or (before the first change) what the old global settings give.
    private var style: SystemStyle {
        if let own = SystemEdits.decode(systemEdits)[theme.id] { return own }
        // A colour theme starts from its own style.
        if let preset = ThemeCatalog.base(id: theme.id).systemStyle { return preset }
        let defaults = SharedStore.defaults
        var start = SystemStyle()
        start.roundness = defaults.object(forKey: SettingKey.keyRoundness) as? Double ?? SettingDefault.keyRoundness
        start.surface = defaults.string(forKey: SettingKey.keySurface) ?? SettingDefault.keySurface
        start.border = defaults.string(forKey: SettingKey.keyBorderStyle) ?? SettingDefault.keyBorderStyle
        start.glow = defaults.string(forKey: SettingKey.keyGlow) ?? SettingDefault.keyGlow
        return start
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<SystemStyle, Value>) -> Binding<Value> {
        return Binding(get: { style[keyPath: keyPath] }, set: { value in
            var next = style
            next[keyPath: keyPath] = value
            systemEdits = SystemEdits.setting(next, for: theme.id, in: systemEdits)
        })
    }

    /// Real Liquid Glass keys are glass: they have no surface, outline or fill of their own to change.
    private var glassKeys: Bool {
        guard theme.kind == .liquidGlass else { return false }
        if #available(iOS 26, *) { return true }
        return false
    }

    /// Whether the keys have an outline (Auto: every theme but Native), so its width means something.
    private var hasBorder: Bool {
        switch style.border {
        case "none": return false
        case "auto": return !theme.hasSolidKeys || style.borderWidth != nil
        default: return true
        }
    }

    var body: some View {
        Section {
            SegmentedChoice(names: [tr("Square"), tr("Slight"), tr("Standard"), tr("Round")],
                            selected: corners.firstIndex { same($0, style.roundness) }) { binding(\.roundness).wrappedValue = corners[$0] }
            GlassSlider(title: tr("Roundness"), symbol: "app", value: binding(\.roundness), range: SystemStyle.roundnessRange,
                        step: 0.02) { DeviceMetrics.points($0 * 22) }
        } header: {
            SectionHeader(tr("Corners"), symbol: "app", color: .indigo)
        }
        .glassRows()

        // Real Liquid Glass keys are glass: no surface, outline, glow or solidity of their own, so none of that is
        // offered for them.
        if !glassKeys {
            Section {
                SegmentedChoice(title: tr("Surface"), names: [tr("Auto"), tr("Flat"), tr("Sheen"), tr("Raised")],
                                selected: surfaces.firstIndex(of: style.surface)) { binding(\.surface).wrappedValue = surfaces[$0] }
                // Only a sheen or raised key has a sheen to make stronger.
                if style.surface == "sheen" || style.surface == "raised" {
                    GlassSlider(title: tr("Sheen strength"), symbol: "sun.max", value: binding(\.sheen),
                                range: SystemStyle.sheenRange, step: 0.05) { String(format: "%.0f%%", $0 * 100) }
                }
                SegmentedChoice(title: tr("Border"), names: [tr("Auto"), tr("None"), tr("Thin"), tr("Bold"), tr("Accent")],
                                selected: borders.firstIndex(of: style.border)) { binding(\.border).wrappedValue = borders[$0] }
                if hasBorder {
                    GlassToggle(title: tr("Own outline width"),
                                subtitle: tr("Set the outline's width in points instead of the border's."),
                                isOn: Binding(get: { style.borderWidth != nil }, set: { on in
                                    binding(\.borderWidth).wrappedValue = on ? 1 : nil
                                }))
                    if let width = style.borderWidth {
                        GlassSlider(title: tr("Outline width"), symbol: "square.dashed",
                                    value: Binding(get: { width }, set: { binding(\.borderWidth).wrappedValue = $0 }),
                                    range: SystemStyle.borderWidthRange, step: 0.1) { String(format: "%.1f pt", $0) }
                    }
                }
                SegmentedChoice(title: tr("Glow"), names: [tr("Off"), tr("Soft"), tr("Strong")],
                                selected: glows.firstIndex(of: style.glow)) { binding(\.glow).wrappedValue = glows[$0] }
            } header: {
                SectionHeader(tr("Key style"), symbol: "sparkles", color: .purple)
            } footer: {
                Text(tr("Auto follows the theme: flat keys, with a thin outline on every theme but Native. Sheen lights the top of each key; Raised adds a shadow under it. Glow and Accent use the accent colour."))
            }
            .glassRows()
        }

        Section {
            if !glassKeys {
                GlassSlider(title: tr("Key solidity"), symbol: "circle.lefthalf.filled", value: binding(\.keyOpacity),
                            range: SystemStyle.keyOpacityRange, step: 0.05) { String(format: "%.0f%%", $0 * 100) }
            }
            GlassSlider(title: tr("Label glow"), symbol: "light.max", value: binding(\.labelGlow),
                        range: 0...1, step: 0.05) { DeviceMetrics.level($0, in: 0...1) }
        } header: {
            SectionHeader(tr("Look"), symbol: "paintpalette", color: .orange)
        } footer: {
            if glassKeys {
                Text(tr("Liquid Glass keys are real glass: they take their colour from what is behind them, so only the label glow can be changed."))
            }
        }
        .glassRows()

        Section {
            Button(role: .destructive) {
                Feedback.delete()
                systemEdits = SystemEdits.setting(nil, for: theme.id, in: systemEdits)
            } label: {
                Label(tr("Reset %@", "\(theme.name)"), systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(ActionButtonStyle())   // its red glass capsule, standing on the backdrop without a card
            .disabled(SystemEdits.decode(systemEdits)[theme.id] == nil)
            .glassOutsideCard()
        } footer: {
            Text(tr("Puts the theme back as it came, with the corners and key style set on the old Keys screen."))
        }
        .glassRows()
    }
}
