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

// MARK: - Long-press characters

/// The user's own characters on a key's hold: "e" -> "€ ə", "1" -> "¹ ½". They come after the language's own accents
/// in the popup (LayoutBuilder.withCustomHolds), on the letters and the digits.
struct LongPressCharactersView: View {
    @State private var holds: [String: String] = Settings.shared.customHolds
    @State private var key = ""
    @State private var characters = ""

    private var sortedKeys: [String] {
        return holds.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var cleanKey: String? {
        guard let first = key.trimmingCharacters(in: .whitespaces).first else { return nil }
        return String(first).lowercased()
    }

    private var cleanCharacters: [String] { return Settings.holdSymbols(characters) }

    private var canSave: Bool { return cleanKey != nil && !cleanCharacters.isEmpty }

    var body: some View {
        PinnedPreview(height: 130) {
            PreviewCard(caption: tr("Touch and hold the key: your characters come after its accents.")) {
                HoldPopupPreview(key: cleanKey ?? "e", characters: cleanCharacters.isEmpty ? ["€", "ə", "ē"] : cleanCharacters)
                    .frame(height: 96)
                    .opacity(canSave ? 1 : 0.6)
            }
        } content: {
            GlassList {
                Section {
                    HStack {
                        Text(tr("Key"))
                        Spacer()
                        TextField(tr("e"), text: Binding(get: { key }, set: { value in
                            key = value.last.map { String($0) } ?? ""
                            if let existing = cleanKey.flatMap({ holds[$0] }), characters.isEmpty { characters = existing }
                        }))
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .frame(maxWidth: 80)
                    }
                    HStack {
                        Text(tr("Characters"))
                        Spacer()
                        TextField(tr("€ ə ē"), text: Binding(get: { characters }, set: { value in
                            characters = Settings.holdSymbols(value).joined(separator: " ")
                        }))
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.body.monospaced())
                    }
                } header: {
                    Text(tr("New characters"))
                } footer: {
                    Text(tr("Type a key, then the characters its hold should offer (up to ten). They come after your language's own accents."))
                }
                .glassRows()

                Section {
                    Button(action: save) {
                        Text(cleanKey.flatMap { holds[$0] } == nil ? tr("Add") : tr("Save"))
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .glassTile(Capsule(), isOn: true)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.45)
                    .glassOutsideCard()
                }
                .glassRows()

                Section {
                    if holds.isEmpty {
                        Text(tr("None yet")).foregroundColor(.secondary)
                    } else {
                        ForEach(sortedKeys, id: \.self) { item in
                            Button {
                                Feedback.tap()
                                key = item
                                characters = Settings.holdSymbols(holds[item] ?? "").joined(separator: " ")
                            } label: {
                                HStack(spacing: 14) {
                                    Text(item)
                                        .font(.title3.weight(.semibold))
                                        .frame(width: 34, height: 38)
                                        .glassTile(RoundedRectangle(cornerRadius: 8, style: .continuous), isOn: false)
                                    Text(Settings.holdSymbols(holds[item] ?? "").joined(separator: "  "))
                                        .font(.body.monospaced())
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .swipeToDelete { remove(item) }
                        }
                    }
                } header: {
                    Text(tr("Your characters"))
                } footer: {
                    if !holds.isEmpty { Text(tr("Tap a key to change it; swipe it left to remove it.")) }
                }
                .glassRows()
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(tr("Long-press characters"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { holds = Settings.shared.customHolds }
    }

    private func save() {
        guard let target = cleanKey, !cleanCharacters.isEmpty else { return }
        var updated = Settings.shared.customHolds
        updated[target] = cleanCharacters.joined()
        Settings.shared.customHolds = updated
        Feedback.success()
        withAnimation(.easeOut(duration: 0.2)) { holds = updated }
        key = ""
        characters = ""
    }

    private func remove(_ item: String) {
        var updated = Settings.shared.customHolds
        updated.removeValue(forKey: item)
        Settings.shared.customHolds = updated
        Feedback.delete()
        withAnimation(.easeOut(duration: 0.2)) { holds = updated }
    }
}

/// A key and the popup its hold opens, as the keyboard draws it.
private struct HoldPopupPreview: View {
    let key: String
    let characters: [String]

    var body: some View {
        CurrentThemeLook { look in
            VStack(spacing: 6) {
                HStack(spacing: 2) {
                    ForEach(characters.indices, id: \.self) { index in
                        Text(characters[index])
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(index == 0 ? look.onAccent : look.textColor)
                            .frame(width: 30, height: 36)
                            .background(index == 0 ? AnyView(look.pill(radius: 8)) : AnyView(Color.clear))
                    }
                }
                .padding(4)
                .background(look.keyShape(.letter, radius: 10))
                Text(key)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(look.textColor)
                    .frame(width: 34, height: 40)
                    .background(look.keyShape(.letter, radius: 8))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
