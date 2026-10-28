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
    private var customTheme: ThemeDefinition { return ThemeCatalog.custom(from: customSpec) }
    private var isCustomSelected: Bool { return themeID == ThemeCatalog.customID }
    private var selected: ThemeDefinition {
        return isCustomSelected ? customTheme : ThemeCatalog.theme(id: themeID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(spacing: 8) {
                    ThemePreview(theme: selected, accent: accent, cornerRadius: 20)
                        .aspectRatio(1.55, contentMode: .fit)
                        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
                    Text(selected.name)
                        .font(.title3.weight(.semibold))
                }
                .padding(.top, 8)

                group("Basics", themes: basics)
                group("Gradients", themes: gradients)
                group("Your own", themes: [customTheme])

                CustomThemeEditor(spec: $customSpec, accent: accent, select: selectCustom)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func selectCustom() {
        if themeID != ThemeCatalog.customID {
            Feedback.tick()
            themeID = ThemeCatalog.customID
        }
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
                    .aspectRatio(1.45, contentMode: .fit)
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

// MARK: - Custom theme

private struct CustomThemeEditor: View {
    @Binding var spec: CustomThemeSpec
    let accent: Color
    let select: () -> Void

    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Customise").font(.headline)

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
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Key opacity")
                    Spacer()
                    Text("\(Int((spec.keyOpacity * 100).rounded()))%")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $spec.keyOpacity, in: 0.2...1.0, step: 0.05) { editing in
                    if !editing { commit() }
                }
                .accessibilityLabel("Key opacity")
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))

            VStack(spacing: 12) {
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
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))

            Button {
                spec = CustomThemeSpec.standard
                Feedback.tick()
                commit()
            } label: {
                Text("Reset custom colours")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Text("Changing a colour here switches the keyboard to your custom theme.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .onDisappear {
            // Save any change still waiting for the delay.
            if saveTask != nil { commit() }
        }
    }

    private func colourRow(_ title: String, _ path: WritableKeyPath<CustomThemeSpec, String>) -> some View {
        ColorPicker(title, selection: Binding(
            get: { Color(hex: spec[keyPath: path]) },
            set: { newColor in
                let hex = newColor.hexString
                guard hex != spec[keyPath: path] else { return }
                spec[keyPath: path] = hex
                scheduleCommit()
            }), supportsOpacity: false)
            .padding(.vertical, 10)
    }

    /// Colour pickers report continuously while dragging: the preview updates at once, the save waits.
    private func scheduleCommit() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            await MainActor.run { commit() }
        }
    }

    private func commit() {
        saveTask?.cancel()
        saveTask = nil
        select()
        ThemeCatalog.saveCustomSpec(spec)
    }
}
