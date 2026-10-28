import SwiftUI

/// The theme picker: a big preview of the current theme and a grid of all themes.
struct ThemesView: View {
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @State private var customSpec = ThemeCatalog.loadCustomSpec()

    private let basics = ThemeCatalog.all.filter { $0.kind != .gradient }
    private let gradients = ThemeCatalog.all.filter { $0.kind == .gradient }
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var accent: Color { return Color.currentAccent(name: accentName, hex: accentHex) }
    private var selected: ThemeDefinition {
        return themeID == ThemeCatalog.customID ? ThemeCatalog.custom(from: customSpec) : ThemeCatalog.theme(id: themeID)
    }

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
                CustomThemeEditor(spec: $customSpec, accent: accent, isSelected: themeID == ThemeCatalog.customID) {
                    if themeID != ThemeCatalog.customID {
                        Feedback.tick()
                        themeID = ThemeCatalog.customID
                    }
                }

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
    let accent: Color
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


// MARK: - Custom theme

private struct CustomThemeEditor: View {
    @Binding var spec: CustomThemeSpec
    let accent: Color
    let isSelected: Bool
    let select: () -> Void

    @State private var pendingSave: DispatchWorkItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom theme").font(.headline)
                Spacer()
                Button {
                    select()
                    commit()
                } label: {
                    Label(isSelected ? "In use" : "Use", systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(isSelected)
            }

            ThemePreview(theme: ThemeCatalog.custom(from: spec), accent: accent, showsStrip: false)
                .aspectRatio(1.7, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                                lineWidth: isSelected ? 3 : 1)
                )
                .onTapGesture { select(); commit() }

            VStack(spacing: 0) {
                colourRow("Backdrop top", \.topHex)
                Divider()
                colourRow("Backdrop bottom", \.bottomHex)
                Divider()
                colourRow("Keys", \.keyHex)
                Divider()
                colourRow("Function keys", \.functionHex)
                Divider()
                colourRow("Text", \.textHex)
            }
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.secondary.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Key opacity")
                    Spacer()
                    Text("\(Int((spec.keyOpacity * 100).rounded()))%").foregroundColor(.secondary)
                }
                Slider(value: $spec.keyOpacity, in: 0.2...1.0, step: 0.05) { editing in
                    if !editing { commit() }
                }
            }

            Toggle("Dark keyboard styling", isOn: Binding(
                get: { spec.isDark },
                set: { spec.isDark = $0; Feedback.tick(); commit() }))

            Picker("Style", selection: Binding(
                get: { spec.style },
                set: { spec.style = $0; Feedback.tick(); commit() })) {
                Text("Gradient").tag("gradient")
                Text("Glass").tag("glass")
            }
            .pickerStyle(.segmented)

            Button("Reset custom colours") {
                spec = CustomThemeSpec.standard
                Feedback.tick()
                commit()
            }
            .font(.footnote)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.secondary.opacity(0.08)))
    }

    private func colourRow(_ title: String, _ path: WritableKeyPath<CustomThemeSpec, String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            ColorPicker(title, selection: Binding(
                get: { Color(hex: spec[keyPath: path]) },
                set: { newColor in
                    let hex = newColor.hexString
                    guard hex != spec[keyPath: path] else { return }
                    spec[keyPath: path] = hex
                    scheduleCommit()
                }), supportsOpacity: false)
                .labelsHidden()
        }
        .padding(.vertical, 8)
    }

    /// Colour pickers report continuously while dragging: the preview updates at once, the save waits.
    private func scheduleCommit() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { select(); commit() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func commit() {
        pendingSave?.cancel()
        ThemeCatalog.saveCustomSpec(spec)
    }
}
