import SwiftUI

/// The theme picker: a big preview of the current theme, a way into its editor, and a grid of all themes: the
/// system ones and one of each designed look.
struct ThemesView: View {
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.themeEdits, store: SharedStore.defaults) private var themeEdits = SettingDefault.themeEdits
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @Environment(\.openScreen) private var openScreen

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var accent: Color { return Color.currentAccent(name: accentName, hex: accentHex) }
    private var selected: ThemeDefinition { return ThemeCatalog.theme(id: themeID, edits: themeEdits) }

    // The chosen theme stays pinned above the grid (PinnedPreview); drag the bar under it to make it smaller.
    var body: some View {
        PinnedPreview(id: "themes", height: 240, fills: true, resizable: true) {
            PinnedKeyboard()
        } content: {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                header

                if selected.kind != .designed {
                    SystemThemeOptions(glassKeys: glassKeys)
                }

                group(tr("Designed"), themes: ThemeCatalog.designed)
                group(tr("System"), themes: ThemeCatalog.system)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        }
        .navigationTitle(tr("Themes"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The Liquid Glass theme on iOS 26: its keys are real glass, so the key style (surface, border, glow) has
    /// nothing to change (Theme.keySurface / drawsKeyBorder / keyGlow skip them); before iOS 26 they are drawn keys.
    private var glassKeys: Bool {
        guard selected.kind == .liquidGlass else { return false }
        if #available(iOS 26, *) { return true }
        return false
    }

    /// The chosen theme's name and what it is, and for a designed theme the way into its editor.
    private var header: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    Text(selected.name).font(.title3.weight(.semibold))
                    if selected.isEdited {
                        StatusChip(text: tr("Edited"), symbol: "slider.horizontal.3", color: accent)
                    }
                }
                Text(tr(selected.summary))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            if selected.kind == .designed {
                Button {
                    Feedback.tap()
                    openScreen(.themeEditor)
                } label: {
                    Label(tr("Customize %@", "\(selected.name)"), systemImage: "paintbrush.pointed.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundColor(.white)
                        .background(Capsule().fill(accent))
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
            } else {
                Text(tr("System themes follow light and dark mode and take the accent colour and the corners and key style below. Pick a designed theme to customize it."))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func group(_ title: String, themes: [ThemeDefinition]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(themes, id: \.id) { base in
                    let theme = ThemeCatalog.theme(id: base.id, edits: themeEdits)
                    ThemeCard(theme: theme, accent: accent, isSelected: theme.id == themeID) {
                        guard theme.id != themeID else { return }
                        Feedback.choose()
                        themeID = theme.id
                    }
                }
            }
        }
    }
}

/// What only the system themes take: their key corners and key style. A designed theme sets its own in the theme
/// editor. The keyboard reads the same settings (Theme.keyCornerRadius / keySurface / keyBorderStyle / keyGlow).
private struct SystemThemeOptions: View {
    let glassKeys: Bool
    @AppStorage(SettingKey.keyRoundness, store: SharedStore.defaults) private var roundness = SettingDefault.keyRoundness
    @AppStorage(SettingKey.keyGap, store: SharedStore.defaults) private var keyGap = SettingDefault.keyGap
    @AppStorage(SettingKey.keyHeight, store: SharedStore.defaults) private var keyHeight = SettingDefault.keyHeight
    @AppStorage(SettingKey.keySurface, store: SharedStore.defaults) private var surface = SettingDefault.keySurface
    @AppStorage(SettingKey.keyBorderStyle, store: SharedStore.defaults) private var borderStyle = SettingDefault.keyBorderStyle
    @AppStorage(SettingKey.keyGlow, store: SharedStore.defaults) private var glow = SettingDefault.keyGlow

    private let corners: [Double] = [0, 0.12, 0.26, 1]
    private let surfaces = ["auto", "flat", "sheen", "raised"]
    private let borders = ["auto", "none", "thin", "bold", "accent"]
    private let glows = ["off", "soft", "strong"]

    private func same(_ a: Double, _ b: Double) -> Bool { return abs(a - b) < 0.001 }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            card(header: SectionHeader(tr("Corners"), symbol: "app", color: .indigo), footer: nil) {
                SegmentedChoice(names: [tr("Square"), tr("Slight"), tr("Standard"), tr("Round")],
                                selected: corners.firstIndex { same($0, roundness) }) { roundness = corners[$0] }
                GlassSlider(title: tr("Roundness"), symbol: "app", value: $roundness, range: 0...1, step: 0.02) {
                    // The corner radius of a letter key (a share of half its shorter side, Theme.keyCornerRadius).
                    DeviceMetrics.points($0 * min(DeviceMetrics.letterKeyWidth(keyGap: keyGap), keyHeight) / 2)
                }
            }
            card(header: SectionHeader(tr("Key style"), symbol: "sparkles", color: .purple),
                 footer: glassKeys
                    ? tr("Not used by the Liquid Glass theme: its keys are real glass, without a surface, outline or glow of their own. These apply again with any other theme.")
                    : tr("Auto follows the theme: flat keys, with a thin outline on every theme but Native. Sheen lights the top of each key; Raised adds a shadow under it. Glow and Accent use the accent colour.")) {
                Group {
                    SegmentedChoice(title: tr("Surface"), names: [tr("Auto"), tr("Flat"), tr("Sheen"), tr("Raised")],
                                    selected: surfaces.firstIndex(of: surface)) { surface = surfaces[$0] }
                    SegmentedChoice(title: tr("Border"), names: [tr("Auto"), tr("None"), tr("Thin"), tr("Bold"), tr("Accent")],
                                    selected: borders.firstIndex(of: borderStyle)) { borderStyle = borders[$0] }
                    SegmentedChoice(title: tr("Glow"), names: [tr("Off"), tr("Soft"), tr("Strong")],
                                    selected: glows.firstIndex(of: glow)) { glow = glows[$0] }
                }
                .disabled(glassKeys)
                .opacity(glassKeys ? 0.45 : 1)
            }
        }
    }

    private func card<Content: View>(header: SectionHeader, footer: String?,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            header
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 14) { content() }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: GlassMetrics.cardRadius)
            if let footer = footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
            }
        }
    }
}

private extension View {
    @ViewBuilder func drawingGroup(isActive: Bool) -> some View {
        if isActive { drawingGroup() } else { self }
    }
}

/// The whole card (preview, name, spacing around them) is one button.
private struct ThemeCard: View {
    let theme: ThemeDefinition
    let accent: Color
    let isSelected: Bool
    let action: () -> Void

    /// Glass and frosted keys are system materials, which a flattened layer can't draw.
    private var flattens: Bool { return theme.kind != .liquidGlass && theme.style?.frosted != true }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ThemePreview(theme: theme, accent: accent, showsStrip: false, cornerRadius: 14)
                    .aspectRatio(ThemePreview.aspectKeysOnly, contentMode: .fit)
                    // One flattened layer instead of every key's own shadow.
                    .drawingGroup(isActive: flattens)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? accent : Color.primary.opacity(0.12),
                                    lineWidth: isSelected ? 3 : 1))
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(accent)
                                .background(Circle().fill(Color.white).padding(3))
                                .padding(6)
                        }
                    }
                    .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 3)
                HStack(spacing: 4) {
                    Text(theme.name)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if theme.isEdited {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                            .accessibilityLabel(tr("Edited"))
                    }
                }
            }
            .padding(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(theme.isEdited ? tr("%@, edited", "\(theme.name)") : theme.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
