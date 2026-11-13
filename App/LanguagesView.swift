import SwiftUI

// MARK: - Languages

/// The enabled languages, each with its code on a keycap and its letter layout; more are added from a list that can
/// be searched. A language swipes left to be removed; a tap opens its layout.
struct LanguagesView: View {
    @State private var enabled: [String] = Settings.shared.enabledLanguages
    /// The layout picked for each language (read again on every visit, as the languages are).
    @State private var layouts: [String: String] = Settings.shared.letterLayouts

    /// In alphabetical order (a list saved here is stored in that order too).
    private var languages: [Language] { return Language.byName(enabled.compactMap { Language(rawValue: $0) }) }

    var body: some View {
        GlassList {
            Section {
                ForEach(languages, id: \.rawValue) { language in
                    LanguageRow(language: language, layouts: layouts)
                        .swipeToDelete(enabled: languages.count > 1) { remove(language) }
                }
                .searchAnchor("languages.list")
            } footer: {
                Text(tr("Swipe the space bar left or right to switch. Tap a language to change its keyboard layout; swipe it left to remove it."))
            }
            .glassRows()

            if enabled.count < Language.allCases.count {
                Section {
                    NavigationLink {
                        AddLanguageView(enabled: enabled) { language in
                            save(enabled + [language.rawValue])
                        }
                    } label: {
                        HStack(spacing: 12) {
                            IconTile(symbol: "plus", color: .green)
                            Text(tr("Add a language"))
                            Spacer()
                            Text("\(Language.allCases.count - enabled.count)").foregroundColor(.secondary)
                            DisclosureChevron()
                        }
                        .foregroundColor(.primary)
                        .contentShape(Rectangle())
                    }
                }
                .glassRows()
            }
        }
        .glassScreen()
        .navigationTitle(tr("Languages"))
        .navigationBarTitleDisplayMode(.inline)
        // Read again on every visit: the screen is built once with the parent, so the starting value above is
        // from when the app opened (reopening it showed the languages of that moment).
        .onAppear {
            enabled = Settings.shared.enabledLanguages
            layouts = Settings.shared.letterLayouts
        }
    }

    private func remove(_ language: Language) {
        guard enabled.count > 1 else { return }
        save(enabled.filter { $0 != language.rawValue })
    }

    private func save(_ list: [String]) {
        let ordered = Language.byName(Language.allCases.filter { list.contains($0.rawValue) }).map { $0.rawValue }
        guard !ordered.isEmpty, ordered != enabled else { return }
        if ordered.count > enabled.count { Feedback.success() } else { Feedback.delete() }
        withAnimation(.easeOut(duration: 0.2)) { enabled = ordered }
        Settings.shared.enabledLanguages = ordered
        // (A removed language's files are left for now: the keyboard may be reading them as they are removed.)
        LanguageData.prepareInBackground(enabled: ordered, removeOthers: false)
    }
}

/// A language's name with its code on a keycap, and its own name under it where that differs.
private struct LanguageName: View {
    let language: Language

    var body: some View {
        HStack(spacing: 12) {
            KeycapLabel(text: language.rawValue.uppercased())
            VStack(alignment: .leading, spacing: 2) {
                Text(language.localizedName).foregroundColor(.primary)
                if language.displayName != language.localizedName {
                    Text(language.displayName).font(.footnote).foregroundColor(.secondary)
                }
            }
        }
    }
}

/// A language in the Languages list: its name and its letter layout, opening the layout screen (languages that are
/// not written with a-z keep their own layout and open nothing).
private struct LanguageRow: View {
    let language: Language
    let layouts: [String: String]
    @Environment(\.swipeFade) private var swipeFade

    var body: some View {
        if language.supportsOtherLayouts {
            ScreenRow(.languageLayout(language.rawValue)) {
                HStack {
                    LanguageName(language: language)
                    Spacer(minLength: 8)
                    Text(tr(LetterLayout.stored(in: layouts, for: language.rawValue).displayName))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .opacity(swipeFade)   // fades as the Delete button comes over it; the name stays
                }
            }
            .buttonStyle(NoPressStyle())   // nothing lights up while the row slides, as in the learned words
        } else {
            LanguageName(language: language)
        }
    }
}

/// The languages that are not enabled yet, with a search field; picking one adds it and stays, to add more.
private struct AddLanguageView: View {
    let add: (Language) -> Void
    /// The languages enabled so far, this visit's additions included (picking one leaves the list open for more).
    @State private var enabled: [String]
    @State private var query = ""

    init(enabled: [String], add: @escaping (Language) -> Void) {
        self._enabled = State(initialValue: enabled)
        self.add = add
    }

    /// The languages left, by name; with something typed, the ones whose name (in the app's language or their
    /// own) or code has it.
    private var matches: [Language] {
        let rest = Language.byName(Language.allCases.filter { !enabled.contains($0.rawValue) })
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return rest }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return rest.filter { language in
            return language.localizedName.range(of: trimmed, options: options) != nil
                || language.displayName.range(of: trimmed, options: options) != nil
                || language.rawValue.range(of: trimmed, options: options) != nil
        }
    }

    var body: some View {
        GlassList {
            Section {
                if matches.isEmpty {
                    Text(tr("No matching languages")).foregroundColor(.secondary)
                } else {
                    ForEach(matches, id: \.rawValue) { language in
                        Button {
                            add(language)
                            withAnimation(.easeOut(duration: 0.2)) { enabled.append(language.rawValue) }
                        } label: {
                            HStack {
                                LanguageName(language: language)
                                Spacer(minLength: 8)
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.tint)
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
            .glassRows()
        }
        .glassScreen()
        .glassSearchable(text: $query, prompt: tr("Search languages"))
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(tr("Add a language"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Learned words

/// Words the keyboard learned (ones no dictionary has, used at least twice), one list for every language, with a
/// search field and swipe to remove.
struct LearnedWordsView: View {
    /// The stored (lower-case) word, and how it is written.
    @State private var words: [(word: String, shown: String)] = []
    @State private var query = ""

    /// The words that match the search.
    private var matches: [(word: String, shown: String)] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return words }
        return words.filter { $0.shown.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    /// How many words there are (and, while searching, how many of them match).
    private var countText: String {
        let shown = matches.count
        return shown == words.count ? "\(words.count)" : "\(shown) / \(words.count)"
    }

    var body: some View {
        GlassList {
            Section {
                if words.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        IconTile(symbol: "character.book.closed", color: .brown)
                        Text(tr("No learned words yet")).font(.headline)
                        Text(tr("A word that isn't in the dictionary is learned once you have typed it twice, or when you tap it in the suggestion bar. Learned words work in every language."))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 6)
                } else if matches.isEmpty {
                    Text(tr("No matching words")).foregroundColor(.secondary)
                } else {
                    ForEach(matches, id: \.word) { entry in
                        Text(entry.shown)
                            .swipeToDelete { remove(entry.word) }
                    }
                }
            } header: {
                if !words.isEmpty {
                    Text(verbatim: countText).monospacedDigit()
                }
            } footer: {
                if !words.isEmpty && !matches.isEmpty {
                    Text(tr("Learned words work in every language. Swipe a word left to remove it."))
                }
            }
            .glassRows()
        }
        .glassScreen()
        .glassSearchable(text: $query, prompt: tr("Search learned words"))
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .navigationTitle(tr("Learned words"))
        .navigationBarTitleDisplayMode(.inline)
        // Reloaded on every visit: a NavigationLink builds this view's initial state only once.
        .onAppear { words = Settings.shared.learnedWordEntries() }
    }

    private func remove(_ word: String) {
        Settings.shared.removeLearnedWord(word)
        Feedback.delete()
        withAnimation(.easeOut(duration: 0.2)) { words.removeAll { $0.word == word } }
    }
}
