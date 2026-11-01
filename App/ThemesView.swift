import SwiftUI

/// The theme picker: a big preview of the current theme and a grid of all themes.
struct ThemesView: View {
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex

    private let basics = ThemeCatalog.all.filter { $0.kind != .colored }
    /// The key-colour themes by heading, in catalogue order.
    private let colourGroups: [ThemeGroup] = {
        var groups: [ThemeGroup] = []
        for theme in ThemeCatalog.all where theme.kind == .colored {
            if let index = groups.firstIndex(where: { $0.title == theme.group }) {
                groups[index].themes.append(theme)
            } else {
                groups.append(ThemeGroup(title: theme.group, themes: [theme]))
            }
        }
        return groups
    }()
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var accent: Color { return Color.currentAccent(name: accentName, hex: accentHex) }
    private var selected: ThemeDefinition { return ThemeCatalog.theme(id: themeID) }

    // The chosen theme stays pinned above the grid (PinnedPreview); drag the bar under it to resize it.
    var body: some View {
        PinnedPreview(id: "themes", height: 240, fills: true) {
            PinnedKeyboard()
        } content: {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(selected.name)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

                group("Basics", themes: basics)
                ForEach(colourGroups) { entry in
                    group(entry.title, themes: entry.themes)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func group(_ title: String, themes: [ThemeDefinition]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(themes, id: \.id) { theme in
                    ThemeCard(theme: theme, accent: accent, isSelected: theme.id == themeID) {
                        guard theme.id != themeID else { return }
                        Feedback.tick()
                        themeID = theme.id
                    }
                }
            }
        }
    }
}

private struct ThemeGroup: Identifiable {
    let title: String
    var themes: [ThemeDefinition]
    var id: String { return title }
}

/// The whole card (preview, name, spacing around them) is one button.
private struct ThemeCard: View {
    let theme: ThemeDefinition
    let accent: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ThemePreview(theme: theme, accent: accent, showsStrip: false, cornerRadius: 14)
                    .aspectRatio(ThemePreview.aspectKeysOnly, contentMode: .fit)
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
                Text(theme.name)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .padding(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
