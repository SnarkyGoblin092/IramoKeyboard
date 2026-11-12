import SwiftUI

// MARK: - Letter layout of a language

/// Picks the letter layout of one language (QWERTY, AZERTY, Dvorak, Colemak...). The language's own letters beyond
/// a-z stay on the keys, at the end of their rows. The keyboard reads it as it opens (Prefs.letterLayouts).
struct LanguageLayoutView: View {
    let language: Language
    @State private var layouts: [String: String] = Settings.shared.letterLayouts

    private var chosen: LetterLayout { return LetterLayout.stored(in: layouts, for: language.rawValue) }

    var body: some View {
        PinnedPreview(height: 150) {
            PreviewCard(caption: tr("%@ on %@", tr(chosen.displayName), language.localizedName)) {
                LayoutKeysPreview(rows: chosen.apply(to: language.defaultLetterRows))
                    .frame(height: 112)
            }
        } content: {
            GlassList {
                Section {
                    ForEach(LetterLayout.allCases, id: \.self) { layout in
                        Button {
                            choose(layout)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(tr(layout.displayName)).foregroundColor(.primary)
                                    Text(tr(layout.note)).font(.footnote).foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(firstRow(of: layout))
                                        .font(.footnote.monospaced())
                                        .foregroundColor(.secondary)
                                }
                                Spacer(minLength: 8)
                                if layout == chosen {
                                    Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(.tint)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                } footer: {
                    Text(tr("Letters of %@ beyond a-z stay on the keys, at the end of their rows. Swiping and auto-correction follow the layout.", language.localizedName))
                }
                .glassRows()
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(language.localizedName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { layouts = Settings.shared.letterLayouts }
    }

    /// The layout's top row, as a hint of what it is.
    private func firstRow(of layout: LetterLayout) -> String {
        return (layout.apply(to: language.defaultLetterRows).first ?? []).joined(separator: " ").uppercased()
    }

    private func choose(_ layout: LetterLayout) {
        guard layout != chosen else { return }
        Feedback.choose()
        var updated = Settings.shared.letterLayouts
        if layout == .standard {
            updated.removeValue(forKey: language.rawValue)
        } else {
            updated[language.rawValue] = layout.rawValue
        }
        Settings.shared.letterLayouts = updated
        withAnimation(.easeOut(duration: 0.2)) { layouts = updated }
    }
}

/// The letter keys of a layout, drawn small: each row centred, like the keyboard.
struct LayoutKeysPreview: View {
    let rows: [[String]]

    var body: some View {
        CurrentThemeLook { look in
            keys(look)
        }
    }

    private func keys(_ look: ThemeLook) -> some View {
        GeometryReader { geometry in
            let longest = CGFloat(max(rows.map { $0.count }.max() ?? 10, 10))
            let gap: CGFloat = 4
            let keyWidth = max(10, (geometry.size.width - gap * (longest - 1)) / longest)
            let keyHeight = min(36, (geometry.size.height - gap * CGFloat(rows.count - 1)) / CGFloat(max(rows.count, 1)))
            VStack(spacing: gap) {
                ForEach(rows.indices, id: \.self) { index in
                    HStack(spacing: gap) {
                        ForEach(rows[index].indices, id: \.self) { column in
                            Text(rows[index][column])
                                .font(.system(size: min(18, keyWidth * 0.55), weight: .regular))
                                .foregroundColor(look.textColor)
                                .frame(width: keyWidth, height: keyHeight)
                                .background(look.keyShape(.letter, radius: 5))
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: rows[index])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
