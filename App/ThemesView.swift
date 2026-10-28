import SwiftUI

/// The theme picker: a big preview of the current theme and a grid of all themes.
struct ThemesView: View {
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent

    private let basics = ThemeCatalog.all.filter { $0.kind != .gradient }
    private let gradients = ThemeCatalog.all.filter { $0.kind == .gradient }
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var accent: AccentChoice { return AccentChoice(rawValue: accentName) ?? .blue }
    private var selected: ThemeDefinition { return ThemeCatalog.theme(id: themeID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ThemePreview(theme: selected, accent: accent)
                    .aspectRatio(1.55, contentMode: .fit)
                    .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
                    .padding(.top, 8)

                Text(selected.name)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)

                group("Basics", themes: basics)
                group("Gradients", themes: gradients)

                if selected.kind == .liquidGlass {
                    Text("Liquid Glass uses iOS 26's glass effect on the keys, suggestion strip and pop-ups. On older iOS versions it falls back to a frosted look.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func group(_ title: String, themes: [ThemeDefinition]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            LazyVGrid(columns: columns, spacing: 14) {
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

private struct ThemeCard: View {
    let theme: ThemeDefinition
    let accent: AccentChoice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ThemePreview(theme: theme, accent: accent, showsStrip: false)
                    .aspectRatio(1.45, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                                    lineWidth: isSelected ? 3 : 1)
                    )
                HStack(spacing: 4) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                    }
                    Text(theme.name).font(.subheadline)
                }
                .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
