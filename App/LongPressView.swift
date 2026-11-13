import SwiftUI

// MARK: - Long-press characters

/// The user's own characters on a key's hold: "e" -> "€ ə", "1" -> "¹ ½". They come after the language's own accents
/// in the popup (LayoutBuilder.withCustomHolds), on the letters and the digits.
///
/// The keyboard is the editor: tap a key on the keyboard pinned at the top and its hold opens under it, the
/// language's own accents first (dimmed, they cannot be changed here) and then the user's characters. Characters are
/// added by typing them or by tapping a suggestion, and saved at once; a tap on one moves or removes it. A key that
/// has characters of the user's own is ringed in the accent and carries their number; all such keys are listed at
/// the bottom, above the button that removes every one of them.
struct LongPressCharactersView: View {
    @State private var holds: [String: String] = Settings.shared.customHolds
    /// The key being edited.
    @State private var selected: String?
    /// Asking before every key's characters are removed.
    @State private var confirmingClear = false
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

    /// How many characters of the user's own each key has.
    private var counts: [String: Int] {
        return holds.mapValues { Settings.holdSymbols($0).count }.filter { $0.value > 0 }
    }

    private func own(_ key: String) -> [String] { return Settings.holdSymbols(holds[key] ?? "") }

    private func builtIn(_ key: String) -> [String] { return language.accents[key] ?? [] }

    /// Characters worth offering for the key that it does not have yet.
    private func ideas(for key: String) -> [String] {
        let taken = Set(own(key) + builtIn(key))
        return (HoldIdeas.table[key] ?? []).filter { !taken.contains($0) }
    }

    var body: some View {
        PinnedPreview(height: 238, fills: true, minimumHeight: 190) {
            VStack(spacing: 6) {
                HoldKeyboard(rows: rows, counts: counts, selected: selected) { key in pick(key) }
                legend
            }
        } content: {
            GlassList {
                if let key = selected {
                    editor(key)
                } else {
                    hint
                }
                overview
                clearAll
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

    /// What the mark on the keys means, and how many keys carry it.
    private var legend: some View {
        let keys = counts.count
        return HStack(spacing: 6) {
            Text(keys == 0
                 ? tr("Keys with your characters show how many they have.")
                 : (keys == 1 ? tr("1 key has your characters.") : tr("%@ keys have your characters.", "\(keys)")))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: The key being edited

    @ViewBuilder private func editor(_ key: String) -> some View {
        let mine = own(key)
        let fixed = builtIn(key)
        let offered = ideas(for: key)
        let full = mine.count >= Settings.holdSymbolsLimit
        Section {
            HoldEditor(fixed: fixed, excluded: key, characters: mine,
                       emptyNote: tr("Nothing yet. Type characters below, or tap a suggestion."),
                       change: { list in store(list, for: key) })
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
                Spacer(minLength: 0)
            }
            .textCase(nil)
        } footer: {
            Text(fixed.isEmpty
                 ? tr("Tap one of your characters to move or remove it.")
                 : tr("The dimmed ones are your language's own accents; yours come after them. Tap one of yours to move or remove it."))
        }
        .glassRows()
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
                IconTile(symbol: "hand.point.up.left.fill", color: .purple)
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
                            KeycapLabel(text: item, color: item == selected ? .accentColor : .gray)
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
                SectionHeader(tr("Your characters"), symbol: "character.textbox", color: .purple)
            } footer: {
                Text(tr("Tap a key to change it; swipe it left to remove it."))
            }
            .glassRows()
        }
    }

    /// The way back to a keyboard without any characters of the user's own. Red, and it asks first.
    private var clearAll: some View {
        Section {
            Button(role: .destructive) {
                Feedback.danger()
                confirmingClear = true
            } label: {
                Label(tr("Delete all custom characters"), systemImage: "trash")
            }
            .buttonStyle(ActionButtonStyle())
            .disabled(holds.isEmpty)
            .confirmationDialog(tr("Delete all custom characters?"), isPresented: $confirmingClear, titleVisibility: .visible) {
                Button(tr("Delete"), role: .destructive) {
                    Settings.shared.customHolds = [:]
                    Feedback.warning()
                    holds = [:]
                }
                Button(tr("Cancel"), role: .cancel) {}
            } message: {
                Text(tr("Every key goes back to its language's own accents."))
            }
            .glassOutsideCard()
        }
        .glassRows()
    }

    // MARK: Changes (each is saved at once)

    private func pick(_ key: String) {
        guard key != selected else { return }
        Feedback.tap()
        withAnimation(.easeOut(duration: 0.2)) { selected = key }
    }

    /// Saves a key's characters. A key left with none goes from the list under the editor: that is done at once,
    /// without an animation (an animated removal takes a row out while it is still being drawn).
    private func store(_ characters: [String], for key: String) {
        var updated = Settings.shared.customHolds
        if characters.isEmpty {
            updated.removeValue(forKey: key)
        } else {
            updated[key] = characters.joined()
        }
        Settings.shared.customHolds = updated
        if updated.count == holds.count {
            withAnimation(.easeOut(duration: 0.2)) { holds = updated }
        } else {
            holds = updated
        }
    }

    /// A suggestion tapped: added to the key if it still fits.
    private func add(_ character: String, to key: String) {
        var list = own(key)
        guard !list.contains(character), list.count < Settings.holdSymbolsLimit else {
            Feedback.threshold()
            return
        }
        list.append(character)
        Feedback.choose()
        store(list, for: key)
    }
}

/// The keyboard to pick a key on: the digits and the letters in the chosen theme's look. The key being edited is
/// lit in the accent; a key with characters of the user's own is ringed in the accent and carries their number.
private struct HoldKeyboard: View {
    let rows: [[String]]
    let counts: [String: Int]
    let selected: String?
    let pick: (String) -> Void

    var body: some View {
        CurrentThemeLook { look in
            board(look)
                .padding(10)
                .background(ClearGlassCard(cornerRadius: 18).environment(\.colorScheme, look.dark ? .dark : .light))
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
                        ForEach(Array(rows[index].enumerated()), id: \.offset) { item in
                            keyButton(item.element, look: look, width: keyWidth, height: keyHeight)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func keyButton(_ key: String, look: ThemeLook, width: CGFloat, height: CGFloat) -> some View {
        let isSelected = key == selected
        let count = counts[key] ?? 0
        return Button {
            pick(key)
        } label: {
            Text(key)
                .font(.system(size: min(21, width * 0.58), weight: count > 0 ? .semibold : .regular))
                .foregroundColor(isSelected ? look.onAccent : look.textColor)
                .frame(width: width, height: height)
                .background(face(look, selected: isSelected))
                .overlay(mark(count, look: look, selected: isSelected))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key)
        .accessibilityValue(count > 0 ? "\(count)" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private func face(_ look: ThemeLook, selected: Bool) -> some View {
        if selected {
            look.pill(radius: 8)
        } else {
            look.keyShape(.letter, radius: 8)
        }
    }

    /// The mark of a key that has characters of the user's own: a ring in the accent, and their number in the
    /// corner.
    @ViewBuilder private func mark(_ count: Int, look: ThemeLook, selected: Bool) -> some View {
        if count > 0 {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(look.accent, lineWidth: selected ? 0 : 1.5)
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(selected ? look.accent : look.onAccent)
                    .frame(minWidth: 14, minHeight: 14)
                    .background(Circle().fill(selected ? look.onAccent : look.accent))
                    .offset(x: 4, y: -4)
            }
            .allowsHitTesting(false)
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
