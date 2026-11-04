import SwiftUI

/// The theme picker: a big preview of the current theme, a way into its editor, and a grid of all themes.
struct ThemesView: View {
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @AppStorage(SettingKey.systemEdits, store: SharedStore.defaults) private var systemEdits = SettingDefault.systemEdits
    @Environment(\.openScreen) private var openScreen

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var accent: Color { return Color.currentAccent(name: accentName, hex: accentHex) }
    private var selected: ThemeDefinition { return ThemeCatalog.theme(id: themeID) }

    // The chosen theme stays pinned above the grid (PinnedPreview); drag the bar under it to make it smaller.
    var body: some View {
        PinnedPreview(height: 240, fills: true) {
            LiveKeyboard()
        } content: {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                header

                grid
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        }
        .navigationTitle(tr("Themes"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The chosen theme's name and what it is, and the way into its editor.
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
            Button {
                Feedback.tap()
                openScreen(.themeEditor)
            } label: {
                Label(tr("Customize %@", "\(selected.name)"), systemImage: "paintbrush.pointed.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundColor(.white)
                    .glassTile(Capsule(), isOn: true)
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(ThemeCatalog.themes(ThemeCatalog.all), id: \.id) { theme in
                ThemeCard(theme: theme, accent: accent, isSelected: theme.id == themeID) {
                    guard theme.id != themeID else { return }
                    Feedback.choose()
                    themeID = theme.id
                }
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

    /// Glass keys are a system material, which a flattened layer can't draw.
    private var flattens: Bool { return theme.kind != .liquidGlass }

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
                    // The shadow of a plain card shape, not of the whole miniature keyboard (far cheaper to draw).
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black)
                            .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 3))
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
