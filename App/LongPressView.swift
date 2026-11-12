import SwiftUI

// MARK: - Long-press characters

/// The user's own characters on a key's hold: "e" -> "€ ə", "1" -> "¹ ½". They come after the language's own accents
/// in the popup (LayoutBuilder.withCustomHolds), on the letters and the digits.
///
/// The keyboard is the editor: tap a key on the keyboard pinned at the top and its hold opens under it, the
/// language's own accents first (dimmed, they cannot be changed here) and then the user's characters. Characters are
/// added by typing them or by tapping a suggestion, and saved at once; a tap on one moves or removes it. Keys that
/// have characters of the user's own carry a dot, and are listed at the bottom.
struct LongPressCharactersView: View {
    @State private var holds: [String: String] = Settings.shared.customHolds
    /// The key being edited.
    @State private var selected: String?
    /// The characters typed into the field, not added yet.
    @State private var draft = ""
    @FocusState private var typing: Bool
    @AppStorage(SettingKey.language, store: SharedStore.defaults) private var languageCode = SettingDefault.language

    /// The language the keyboard opens in: its letters are the keys, and its accents the ones shown.
    private var language: Language { return LiveKeyboardView.openingLanguage(code: languageCode) }

    /// The digits, then the letters as the keyboard has them (the layout picked for the language).
    private var rows: [[String]] {
        let letters = LetterLayout.stored(in: Settings.shared.letterLayouts, for: language.rawValue)
            .apply(to: language.defaultLetterRows)
        return [["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]] + letters
    }

    private var sortedKeys: [String] {
        return holds.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func own(_ key: String) -> [String] { return Settings.holdSymbols(holds[key] ?? "") }

    private func builtIn(_ key: String) -> [String] { return language.accents[key] ?? [] }

    /// Characters worth offering for the key that it does not have yet.
    private func ideas(for key: String) -> [String] {
        let taken = Set(own(key) + builtIn(key))
        return (HoldIdeas.table[key] ?? []).filter { !taken.contains($0) }
    }

    var body: some View {
        PinnedPreview(height: 214, fills: true, minimumHeight: 176) {
            HoldKeyboard(rows: rows, marked: Set(holds.keys), selected: selected) { key in pick(key) }
        } content: {
            GlassList {
                if let key = selected {
                    editor(key)
                } else {
                    hint
                }
                overview
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(tr("Long-press characters"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            holds = Settings.shared.customHolds
            // A key that already has characters is opened, so the screen shows at once how it works.
            if selected == nil { selected = sortedKeys.first }
        }
    }

    // MARK: The key being edited

    @ViewBuilder private func editor(_ key: String) -> some View {
        let mine = own(key)
        let fixed = builtIn(key)
        let offered = ideas(for: key)
        let full = mine.count >= Settings.holdSymbolsLimit
        Section {
            popup(key, fixed: fixed, mine: mine)
            addField(key, full: full)
            if !offered.isEmpty && !full {
                suggestions(offered, key: key)
            }
            if !mine.isEmpty {
                Button(role: .destructive) {
                    Feedback.delete()
                    store([], for: key)
                } label: {
                    Label(tr("Remove all from this key"), systemImage: "trash")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
        } header: {
            HStack(spacing: 8) {
                KeycapLabel(text: key, size: 26)
                Text(tr("Touch and hold for"))
                Spacer(minLength: 8)
                Text("\(mine.count)/\(Settings.holdSymbolsLimit)").monospacedDigit()
            }
            .textCase(nil)
        } footer: {
            Text(fixed.isEmpty
                 ? tr("Tap one of your characters to move or remove it.")
                 : tr("The dimmed ones are your language's own accents; yours come after them. Tap one of yours to move or remove it."))
        }
        .glassRows()
    }

    /// The key's hold as the keyboard will offer it: the language's accents, then the user's characters.
    @ViewBuilder private func popup(_ key: String, fixed: [String], mine: [String]) -> some View {
        if fixed.isEmpty && mine.isEmpty {
            Text(tr("Nothing yet. Type characters below, or tap a suggestion."))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                ForEach(fixed, id: \.self) { character in
                    HoldCell(character: character, own: false)
                        .accessibilityLabel(tr("%@, from your language", character))
                }
                ForEach(mine, id: \.self) { character in
                    let index = mine.firstIndex(of: character) ?? 0
                    Menu {
                        Button {
                            move(character, by: -1, on: key)
                        } label: {
                            Label(tr("Move earlier"), systemImage: "arrow.left")
                        }
                        .disabled(index == 0)
                        Button {
                            move(character, by: 1, on: key)
                        } label: {
                            Label(tr("Move later"), systemImage: "arrow.right")
                        }
                        .disabled(index >= mine.count - 1)
                        Button(role: .destructive) {
                            remove(character, from: key)
                        } label: {
                            Label(tr("Remove"), systemImage: "trash")
                        }
                    } label: {
                        HoldCell(character: character, own: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            // The popup is laid out left to right, as on the keyboard.
            .environment(\.layoutDirection, .leftToRight)
        }
    }

    /// Characters are typed (or pasted) here, several at once if wanted; return or Add puts them on the key.
    private func addField(_ key: String, full: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            TextField(full ? tr("This key is full") : tr("Type or paste characters"), text: $draft)
                .focused($typing)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onSubmit { commit(to: key) }
                .disabled(full)
            Button(tr("Add")) { commit(to: key) }
                .buttonStyle(ActionButtonStyle(compact: true))
                .disabled(full || draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func suggestions(_ offered: [String], key: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("Suggestions")).font(.subheadline).foregroundColor(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(offered, id: \.self) { character in
                        Button {
                            add(character, to: key)
                        } label: {
                            Text(character)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .strokeBorder(Color.secondary.opacity(0.45),
                                                      style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tr("Add %@", character))
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, 2)
    }

    /// Before a key is picked.
    private var hint: some View {
        Section {
            HStack(spacing: 14) {
                IconTile(symbol: "hand.point.up.left.fill")
                Text(tr("Tap a key above to choose what touching and holding it offers."))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
        .glassRows()
    }

    // MARK: Every key that has characters

    @ViewBuilder private var overview: some View {
        if !holds.isEmpty {
            Section {
                ForEach(sortedKeys, id: \.self) { item in
                    Button {
                        pick(item)
                    } label: {
                        HStack(spacing: 14) {
                            KeycapLabel(text: item, color: item == selected ? .accentColor : .secondary)
                            Text(own(item).joined(separator: "  "))
                                .font(.body.monospaced())
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NoPressStyle())   // the row slides to delete: nothing lights up under the finger
                    .swipeToDelete {
                        Feedback.delete()
                        store([], for: item)
                    }
                }
            } header: {
                SectionHeader(tr("Your characters"), symbol: "character.textbox")
            } footer: {
                Text(tr("Tap a key to change it; swipe it left to remove it."))
            }
            .glassRows()
        }
    }

    // MARK: Changes (each is saved at once)

    private func pick(_ key: String) {
        guard key != selected else { return }
        Feedback.tap()
        draft = ""
        withAnimation(.easeOut(duration: 0.2)) { selected = key }
    }

    private func store(_ characters: [String], for key: String) {
        var updated = Settings.shared.customHolds
        if characters.isEmpty {
            updated.removeValue(forKey: key)
        } else {
            updated[key] = characters.joined()
        }
        Settings.shared.customHolds = updated
        withAnimation(.easeOut(duration: 0.2)) { holds = updated }
    }

    /// Adds every new character of `text` to the key (not the key's own letter, nor one it already offers), up to
    /// the limit.
    private func add(_ text: String, to key: String) {
        var list = own(key)
        let fixed = builtIn(key)
        var added = false
        for character in text where !character.isWhitespace {
            let symbol = String(character)
            if symbol == key || list.contains(symbol) || fixed.contains(symbol) { continue }
            if list.count >= Settings.holdSymbolsLimit { break }
            list.append(symbol)
            added = true
        }
        guard added else {
            Feedback.threshold()
            return
        }
        Feedback.choose()
        store(list, for: key)
    }

    private func commit(to key: String) {
        let text = draft
        draft = ""
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        add(text, to: key)
        typing = true   // the field stays ready for more
    }

    private func remove(_ character: String, from key: String) {
        Feedback.delete()
        store(own(key).filter { $0 != character }, for: key)
    }

    private func move(_ character: String, by step: Int, on key: String) {
        var list = own(key)
        guard let from = list.firstIndex(of: character) else { return }
        let to = from + step
        guard list.indices.contains(to) else { return }
        list.swapAt(from, to)
        Feedback.tick()
        store(list, for: key)
    }
}

/// One character of a hold: the user's own on the accent, the language's dimmed.
private struct HoldCell: View {
    let character: String
    let own: Bool

    var body: some View {
        Text(character)
            .font(.system(size: 21, weight: .medium))
            .foregroundColor(own ? .primary : .secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(own ? Color.accentColor.opacity(0.24) : Color.primary.opacity(0.06)))
            .contentShape(Rectangle())
    }
}

/// The keyboard to pick a key on: the digits and the letters in the chosen theme's look. The key being edited is
/// lit in the accent; a key with characters of the user's own carries a dot.
private struct HoldKeyboard: View {
    let rows: [[String]]
    let marked: Set<String>
    let selected: String?
    let pick: (String) -> Void

    var body: some View {
        CurrentThemeLook { look in
            board(look)
                .padding(10)
                .background(look.backdrop())
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func board(_ look: ThemeLook) -> some View {
        GeometryReader { geometry in
            let longest: CGFloat = CGFloat(max(rows.map { $0.count }.max() ?? 10, 10))
            let gap: CGFloat = 5
            let keyWidth: CGFloat = max(12, (geometry.size.width - gap * (longest - 1)) / longest)
            let count: CGFloat = CGFloat(max(rows.count, 1))
            let keyHeight: CGFloat = min(48, max(20, (geometry.size.height - gap * (count - 1)) / count))
            VStack(spacing: gap) {
                ForEach(rows.indices, id: \.self) { index in
                    HStack(spacing: gap) {
                        ForEach(rows[index], id: \.self) { key in
                            keyButton(key, look: look, width: keyWidth, height: keyHeight)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func keyButton(_ key: String, look: ThemeLook, width: CGFloat, height: CGFloat) -> some View {
        let isSelected = key == selected
        return Button {
            pick(key)
        } label: {
            Text(key)
                .font(.system(size: min(21, width * 0.58), weight: .regular))
                .foregroundColor(isSelected ? look.onAccent : look.textColor)
                .frame(width: width, height: height)
                .background(face(look, selected: isSelected))
                .overlay(alignment: .topTrailing) {
                    if marked.contains(key) {
                        Circle()
                            .fill(isSelected ? look.onAccent : look.accent)
                            .frame(width: 6, height: 6)
                            .padding(4)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private func face(_ look: ThemeLook, selected: Bool) -> some View {
        if selected {
            look.pill(radius: 8)
        } else {
            look.keyShape(.letter, radius: 8)
        }
    }
}

/// Characters people often want on a key's hold, by the key they are looked for on.
private enum HoldIdeas {
    static let table: [String: [String]] = [
        "a": ["@", "ª", "α", "å", "æ", "ā"],
        "b": ["β", "฿", "•"],
        "c": ["©", "¢", "ç", "℃"],
        "d": ["°", "δ", "†", "đ"],
        "e": ["€", "ə", "ε", "ē", "∑"],
        "f": ["ƒ", "℉", "φ"],
        "g": ["γ", "ğ"],
        "h": ["♥", "#", "ħ"],
        "i": ["∞", "ı", "ī", "¡"],
        "j": ["ĵ"],
        "k": ["κ", "₭"],
        "l": ["£", "λ", "ł"],
        "m": ["µ", "™", "♂"],
        "n": ["ñ", "№", "η"],
        "o": ["ø", "œ", "ω", "º"],
        "p": ["π", "¶", "₱"],
        "q": ["¿", "θ"],
        "r": ["®", "√", "ρ", "₹"],
        "s": ["$", "§", "ß", "σ", "š"],
        "t": ["™", "†", "τ", "þ"],
        "u": ["µ", "ū", "υ"],
        "v": ["✓", "∨"],
        "w": ["ω", "₩"],
        "x": ["×", "✗", "ξ"],
        "y": ["¥", "ý", "ÿ"],
        "z": ["ž", "ζ", "ż"],
        "1": ["¹", "½", "⅓", "¼", "₁"],
        "2": ["²", "⅔", "₂"],
        "3": ["³", "¾", "₃"],
        "4": ["⁴", "₄"],
        "5": ["⁵", "⅝", "₅"],
        "6": ["⁶", "₆"],
        "7": ["⁷", "⅞", "₇"],
        "8": ["⁸", "∞", "₈"],
        "9": ["⁹", "₉"],
        "0": ["⁰", "°", "∅", "₀"]
    ]
}
