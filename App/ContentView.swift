import SwiftUI
import UIKit

/// The keyboard's settings. Every section is its own small view, so changing one control only redraws that section.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            // Liquid Glass: frosted rows on the tinted backdrop (Glass.swift).
            List {
                HeaderSection().glassRows()
                TestFieldSection().glassRows()
                TypingSection().glassRows()
                LanguagesSection().glassRows()
                GesturesSection().glassRows()
                FeedbackSection().glassRows()
                AppearanceSection().glassRows()
                ShortcutsSection().glassRows()
                DataSection().glassRows()
                CreditsSection().glassRows()
            }
            .listStyle(.insetGrouped)
            .glassScreen()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .scrollDismissesKeyboard(.interactively)
        }
        .modifier(AccentTint())
        .onAppear {
            Feedback.prepare()
            Settings.shared.removeTouchModel()
        }
    }
}

// MARK: - Sections

/// App name, a few status chips and a hint about what to do next.
private struct HeaderSection: View {
    @State private var status = KeyboardStatus.read()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    // The app icon (AppLogo is a small copy of it, written by scripts/make_icon.py), with the
                    // home screen's corner shape.
                    Image("AppLogo")
                        .resizable()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12.5, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Iramo").font(.title2.weight(.bold))
                        Text("Your words, your keyboard")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Only what still needs setting up is shown.
                if !status.isReady {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8, alignment: .leading)],
                              alignment: .leading, spacing: 8) {
                        if !status.seen {
                            StatusChip(text: "Not set up yet", symbol: "exclamationmark.circle.fill", color: .orange)
                        } else if !status.fullAccess {
                            StatusChip(text: "Full Access off", symbol: "lock.fill", color: .orange)
                        }
                        if !SharedStore.isShared {
                            StatusChip(text: "Not synced", symbol: "arrow.triangle.2.circlepath", color: .red)
                        }
                    }

                    Text(hint)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 6)
        }
        // Read when the screen opens or the app comes back to the front - no polling.
        .onAppear { status = KeyboardStatus.read() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { status = KeyboardStatus.read() }
        }
    }

    private var hint: String {
        if !SharedStore.isShared {
            return "This install can't share settings with the keyboard (no App Group). Install the IPA with iloader."
        }
        if !status.seen {
            return "Add Iramo in Settings > General > Keyboard > Keyboards, turn on Allow Full Access, then open the keyboard once."
        }
        return "Allow Full Access is off: no vibration, and the keyboard can't save recent emoji or learned words."
    }
}

private struct TestFieldSection: View {
    @State private var text = ""

    var body: some View {
        Section {
            TextField("Tap here and type to try it", text: $text)
        } header: {
            SectionHeader("Try the keyboard", symbol: "text.cursor", color: .gray)
        }
    }
}

private struct TypingSection: View {
    var body: some View {
        Section {
            NavigationLink {
                SuggestionsView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Suggestion bar")
                        Text("Word suggestions, how many words, look and speed")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "text.line.first.and.arrowtriangle.forward")
                }
            }
            SettingToggle("Auto-correction", key: SettingKey.autoCorrect, defaultValue: SettingDefault.autoCorrect,
                          subtitle: "Fixes typos, missing accents and missing spaces when you press space")
            SettingToggle("Emoji suggestions", key: SettingKey.emojiSuggestions, defaultValue: SettingDefault.emojiSuggestions,
                          subtitle: "Offers an emoji that matches the word you typed")
            SettingToggle("Auto-capitalization", key: SettingKey.autoCapitalize, defaultValue: SettingDefault.autoCapitalize,
                          subtitle: "Starts each sentence with a capital letter")
            SettingToggle("\u{201C}.\u{201D} shortcut", key: SettingKey.doubleSpacePeriod, defaultValue: SettingDefault.doubleSpacePeriod,
                          subtitle: "Tap the space bar twice to end a sentence")
        } header: {
            SectionHeader("Typing", symbol: "keyboard", color: .blue)
        }
    }
}

private struct GesturesSection: View {
    var body: some View {
        Section {
            NavigationLink {
                GesturesView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gestures")
                        Text("Swipe typing, thumb handoff, flicks, cursor and delete")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "hand.draw")
                }
            }
            NavigationLink {
                HitboxesView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hitboxes")
                        Text("Letter room, adaptive keys and your hit map")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "scope")
                }
            }
        } header: {
            SectionHeader("Gestures & touch", symbol: "hand.draw.fill", color: .teal)
        }
    }
}

private struct FeedbackSection: View {
    var body: some View {
        Section {
            NavigationLink {
                HapticsView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Haptics")
                        Text("Vibration, cursor ticks and key clicks")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                }
            }
            SettingToggle("Key pop-ups", key: SettingKey.keyPopups, defaultValue: SettingDefault.keyPopups,
                          subtitle: "Shows the letter above your finger")
        } header: {
            SectionHeader("Sound & haptics", symbol: "speaker.wave.2.fill", color: .pink)
        }
    }
}

private struct LanguagesSection: View {
    var body: some View {
        Section {
            NavigationLink {
                LanguagesView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Languages")
                    Text("Swipe the space bar left or right to switch")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
        } header: {
            SectionHeader("Languages", symbol: "globe", color: .green)
        }
    }
}

private struct AppearanceSection: View {
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex

    private var accent: Color { return Color.currentAccent(name: accentName, hex: accentHex) }
    private var theme: ThemeDefinition { return ThemeCatalog.theme(id: themeID) }

    var body: some View {
        Section {
            NavigationLink {
                ThemesView()
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    ThemePreview(theme: theme, accent: accent, cornerRadius: 12)
                        .aspectRatio(ThemePreview.aspectWithStrip, contentMode: .fit)
                    HStack {
                        Text("Theme")
                        Spacer()
                        Text(theme.name).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Accent colour")
                Text("The return key and highlights. Colour themes keep their own until you pick one.")
                    .font(.footnote).foregroundColor(.secondary)
                AccentPicker()
            }
            .padding(.vertical, 2)
            AccentCustomRow()

            NavigationLink {
                KeysView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keys")
                        Text("Size, corners, spacing, labels and the space bar")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "keyboard")
                }
            }
            SettingToggle("Key borders", key: SettingKey.keyBorders, defaultValue: SettingDefault.keyBorders,
                          subtitle: "A thin outline around keys on translucent themes")
            SettingToggle("Number row", key: SettingKey.numberRow, defaultValue: SettingDefault.numberRow,
                          subtitle: "Numbers above the letters")
        } header: {
            SectionHeader("Appearance", symbol: "paintpalette.fill", color: .purple)
        }
    }
}

private struct ShortcutsSection: View {
    var body: some View {
        Section {
            NavigationLink {
                ShortcutsView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Text shortcuts")
                    Text("Type a trigger and press space to expand it")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
        } header: {
            SectionHeader("Shortcuts", symbol: "bolt.fill", color: .orange)
        }
    }
}

private struct DataSection: View {
    private enum Action: String {
        case recents, learned, reset

        var title: String {
            switch self {
            case .recents: return "Clear recent emoji?"
            case .learned: return "Forget learned words?"
            case .reset: return "Reset all settings?"
            }
        }

        var message: String {
            switch self {
            case .recents: return "The Recently Used emoji tab will be empty."
            case .learned: return "Words the keyboard picked up while you type will be removed."
            case .reset: return "Your shortcuts, recent emoji and learned words are kept."
            }
        }

        var button: String {
            switch self {
            case .recents: return "Clear"
            case .learned: return "Forget"
            case .reset: return "Reset"
            }
        }
    }

    @State private var pending: Action?
    @State private var note: String?

    var body: some View {
        Section {
            NavigationLink {
                LearnedWordsView()
            } label: {
                Label("Learned words", systemImage: "character.book.closed")
            }
            row(.learned, "Forget learned words", symbol: "text.book.closed")
            row(.recents, "Clear recent emoji", symbol: "clock.arrow.circlepath")
            row(.reset, "Reset all settings", symbol: "arrow.counterclockwise", role: .destructive)
            if let note = note {
                Text(note).font(.footnote).foregroundColor(.secondary)
            }
        } header: {
            SectionHeader("Privacy & data", symbol: "hand.raised.fill", color: .gray)
        } footer: {
            Text("Everything the keyboard learns stays on this device.")
        }
    }

    /// One option with its own confirmation, so the dialog's arrow points at the option that was tapped.
    private func row(_ action: Action, _ title: String, symbol: String, role: ButtonRole? = nil) -> some View {
        Button(role: role) { pending = action } label: { Label(title, systemImage: symbol) }
            .confirmationDialog(action.title,
                                isPresented: Binding(get: { pending == action }, set: { if !$0 { pending = nil } }),
                                titleVisibility: .visible) {
                Button(action.button, role: .destructive) { perform(action) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(action.message)
            }
    }

    private func perform(_ action: Action) {
        switch action {
        case .recents:
            Settings.shared.clearRecentEmoji()
            note = "Recent emoji cleared."
        case .learned:
            Settings.shared.clearLearnedWords()
            note = "Learned words forgotten."
        case .reset:
            Settings.shared.resetPreferences()
            NotificationCenter.default.post(name: .hunKeysSettingsReset, object: nil)
            note = "Settings reset to defaults."
        }
        Feedback.tick()
    }
}

/// Credits and licences for the word data, emoji data and icons the app ships (LicensesView).
private struct CreditsSection: View {
    var body: some View {
        Section {
            NavigationLink {
                LicensesView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Licences")
                    Text("Copyright, and the word lists, emoji data and icons the keyboard uses")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
        } header: {
            SectionHeader("Acknowledgements", symbol: "info.circle.fill", color: .gray)
        }
    }
}

// MARK: - Status

struct KeyboardStatus {
    var seen: Bool
    var fullAccess: Bool

    static func read() -> KeyboardStatus {
        let store = SharedStore.defaults
        return KeyboardStatus(seen: store.double(forKey: SettingKey.lastSeen) > 0,
                              fullAccess: store.bool(forKey: SettingKey.fullAccess))
    }

    /// Nothing left to set up: the header then shows no chips or hint.
    var isReady: Bool { return seen && fullAccess && SharedStore.isShared }
}

// MARK: - Shortcuts

struct ShortcutsView: View {
    @State private var items: [TextShortcut] = Settings.shared.shortcuts
    @State private var trigger = ""
    @State private var phrase = ""

    private var canAdd: Bool {
        return !trigger.trimmingCharacters(in: .whitespaces).isEmpty
            && !phrase.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // Grouped cards rather than a Form, so the shortcuts swipe to delete like the languages do.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                CardHeader("New shortcut")
                VStack(spacing: 0) {
                    TextField("Trigger (e.g. omw)", text: $trigger)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .cardRow()
                    Divider().padding(.leading, 16)
                    TextField("Phrase (e.g. On my way!)", text: $phrase)
                        .cardRow()
                    Divider().padding(.leading, 16)
                    Button(action: add) {
                        Text("Add").cardRow().contentShape(Rectangle())
                    }
                    .disabled(!canAdd)
                }
                .groupedCard()
                .padding(.bottom, 16)

                CardHeader("Your shortcuts")
                if items.isEmpty {
                    Text("None yet").foregroundColor(.secondary).cardRow().groupedCard()
                } else {
                    DeletableCard(items: items, id: { $0.id }, onDelete: remove) { item in
                        VStack(alignment: .leading) {
                            Text(item.trigger).font(.headline)
                            Text(item.phrase).font(.subheadline).foregroundColor(.secondary)
                        }
                        .cardRow()
                        .padding(.vertical, 6)
                    }
                    CardFooter("Swipe a shortcut left to remove it.")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(GlassBackdrop())
        .navigationTitle("Text shortcuts")
        .navigationBarTitleDisplayMode(.inline)
        // Read again on every visit: the screen is built once with the parent, so the starting value above is
        // from when the app opened.
        .onAppear { items = Settings.shared.shortcuts }
    }

    private func add() {
        let key = trigger.trimmingCharacters(in: .whitespaces)
        let text = phrase.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !text.isEmpty else { return }
        items.removeAll { $0.trigger.lowercased() == key.lowercased() }
        items.append(TextShortcut(trigger: key, phrase: text))
        save()
        trigger = ""
        phrase = ""
    }

    private func remove(_ item: TextShortcut) {
        Feedback.tick()
        withAnimation(.easeOut(duration: 0.2)) { items.removeAll { $0.id == item.id } }
        save()
    }

    private func save() {
        Settings.shared.shortcuts = items
    }
}

// MARK: - Languages

/// The enabled languages only; more are added from a separate list. Drawn as its own grouped card (not a List)
/// so the swipe-to-delete button sits inside the row and the card keeps its corners while swiping.
struct LanguagesView: View {
    @State private var enabled: [String] = Settings.shared.enabledLanguages

    private var languages: [Language] { return enabled.compactMap { Language(rawValue: $0) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                DeletableCard(items: languages, id: { $0.rawValue }, canDelete: languages.count > 1, onDelete: remove) { language in
                    Text(language.displayName).cardRow()
                }

                CardFooter("Swipe the space bar left or right to switch. Swipe a language left to remove it.")

                if enabled.count < Language.allCases.count {
                    NavigationLink {
                        AddLanguageView(enabled: enabled) { language in
                            save(enabled + [language.rawValue])
                        }
                    } label: {
                        HStack {
                            Label("Add a language", systemImage: "plus")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .groupedCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background(GlassBackdrop())
        .navigationTitle("Languages")
        .navigationBarTitleDisplayMode(.inline)
        // Read again on every visit: the screen is built once with the parent, so the starting value above is
        // from when the app opened (reopening it showed the languages of that moment).
        .onAppear { enabled = Settings.shared.enabledLanguages }
    }

    private func remove(_ language: Language) {
        guard enabled.count > 1 else { return }
        save(enabled.filter { $0 != language.rawValue })
    }

    private func save(_ list: [String]) {
        let ordered = Language.allCases.map { $0.rawValue }.filter { list.contains($0) }
        guard !ordered.isEmpty, ordered != enabled else { return }
        Feedback.tick()
        withAnimation(.easeOut(duration: 0.2)) { enabled = ordered }
        Settings.shared.enabledLanguages = ordered
    }
}

private extension View {
    /// The rounded glass card of a grouped list (Liquid Glass on iOS 26).
    func groupedCard() -> some View {
        let radius = GlassMetrics.cardRadius
        return self
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .glassCard(cornerRadius: radius)
    }

    /// A row of a grouped card: full width, list-like insets and height.
    func cardRow() -> some View {
        return self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
    }
}

/// The title above a grouped card, like a list section header.
private struct CardHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        if #available(iOS 26, *) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.secondary).padding(.horizontal, 16)
        } else {
            Text(title.uppercased()).font(.footnote).foregroundColor(.secondary).padding(.horizontal, 16)
        }
    }
}

/// The note under a grouped card, like a list section footer.
private struct CardFooter: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
    }
}

/// A grouped card of rows that each swipe left to delete (SwipeToDeleteRow), as on the Languages screen.
private struct DeletableCard<Item, ID: Hashable, Row: View>: View {
    let items: [Item]
    let id: (Item) -> ID
    var canDelete = true
    let onDelete: (Item) -> Void
    @ViewBuilder let row: (Item) -> Row

    private struct Entry: Identifiable {
        let id: ID
        let index: Int
        let item: Item
    }

    var body: some View {
        let entries = items.enumerated().map { Entry(id: id($0.element), index: $0.offset, item: $0.element) }
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                SwipeToDeleteRow(canDelete: canDelete) {
                    onDelete(entry.item)
                } content: {
                    row(entry.item)
                }
                if entry.index < entries.count - 1 {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .groupedCard()
    }
}

/// A row that slides left to show a red Delete button inside the row itself; a long swipe deletes at once.
private struct SwipeToDeleteRow<Content: View>: View {
    let canDelete: Bool
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var settled: CGFloat = 0
    /// Whether the current drag is a sideways swipe (decided once, at its start); nil until it is known.
    @State private var horizontal: Bool?
    private let buttonWidth: CGFloat = 84
    /// How far the Delete button may grow: a long swipe that reaches it deletes at once.
    private let maxReveal: CGFloat = 200
    private let settle = Animation.spring(response: 0.35, dampingFraction: 0.86)

    var body: some View {
        // The row stays put (the name never slides off screen); the Delete button grows in from the right edge.
        content()
            .contentShape(Rectangle())   // the card's glass shows through; the whole row still takes taps
            .onTapGesture { close() }
            .overlay(alignment: .trailing) {
                Button(action: delete) {
                    Text("Delete")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(width: max(0, -offset))
                        .frame(maxHeight: .infinity)
                        .background(Color.red)
                        .clipped()
                }
                .buttonStyle(.plain)
                .allowsHitTesting(offset < 0)
            }
            // Alongside the scroll view's own pan, so the row follows the finger from the first point instead
            // of waiting for the scroll view to give up (the stall partway into a slow swipe).
            .simultaneousGesture(drag, including: canDelete ? .all : .subviews)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                let dx = value.translation.width, dy = value.translation.height
                if horizontal == nil { horizontal = abs(dx) > abs(dy) }
                guard horizontal == true else { return }
                let target = min(0, settled + dx)
                // Past the full-delete point the button resists instead of stopping dead.
                let resisted = target < -maxReveal ? -maxReveal + (target + maxReveal) * 0.25 : target
                if (offset > -maxReveal) != (resisted > -maxReveal) { Feedback.tick() }   // crossing it
                offset = resisted
            }
            .onEnded { value in
                defer { horizontal = nil }
                guard horizontal == true else { return }
                let end = min(0, settled + value.translation.width)
                if end <= -maxReveal {
                    delete()
                    return
                }
                // A quick flick counts as far as it was heading.
                let heading = min(0, settled + value.predictedEndTranslation.width)
                let open = min(end, heading) < -buttonWidth / 2
                withAnimation(settle) { offset = open ? -buttonWidth : 0 }
                settled = open ? -buttonWidth : 0
            }
    }

    private func close() {
        guard offset != 0 else { return }
        withAnimation(settle) { offset = 0 }
        settled = 0
    }

    private func delete() {
        offset = 0
        settled = 0
        onDelete()
    }
}

/// The languages that are not enabled yet; picking one adds it and goes back.
private struct AddLanguageView: View {
    let enabled: [String]
    let add: (Language) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(Language.allCases.filter { !enabled.contains($0.rawValue) }, id: \.rawValue) { language in
                Button {
                    add(language)
                    dismiss()
                } label: {
                    Text(language.displayName).foregroundColor(.primary)
                }
            }
            .glassRows()
        }
        .glassScreen()
        .navigationTitle("Add a language")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Learned words

/// Words the keyboard learned (ones no dictionary has, used at least twice), per language, with a search
/// field and swipe to remove.
struct LearnedWordsView: View {
    @State private var words: [String: [String]] = [:]
    @State private var query = ""

    /// The words of each language that match the search.
    private func matches(for language: Language) -> [String] {
        let list = words[language.rawValue] ?? []
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return list }
        return list.filter { $0.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    private var languages: [Language] {
        return Language.allCases.filter { !matches(for: $0).isEmpty }
    }

    // Grouped cards rather than a List, so the words swipe to delete like the languages do.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if words.isEmpty {
                    Text("No learned words yet").foregroundColor(.secondary).cardRow().groupedCard()
                    CardFooter("A word that isn't in the dictionary is learned once you have typed it twice, or when you tap it in the suggestion bar.")
                } else if languages.isEmpty {
                    Text("No matching words").foregroundColor(.secondary).cardRow().groupedCard()
                }
                ForEach(languages, id: \.rawValue) { language in
                    CardHeader(language.displayName)
                    DeletableCard(items: matches(for: language), id: { $0 }, onDelete: { remove([$0], from: language) }) { word in
                        Text(word).cardRow()
                    }
                    .padding(.bottom, 16)
                }
                if !languages.isEmpty {
                    CardFooter("Swipe a word left to remove it.")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background(GlassBackdrop())
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search learned words")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .navigationTitle("Learned words")
        .navigationBarTitleDisplayMode(.inline)
        // Reloaded on every visit: a NavigationLink builds this view's initial state only once.
        .onAppear { words = LearnedWordsView.load() }
    }

    private static func load() -> [String: [String]] {
        var result: [String: [String]] = [:]
        for language in Language.allCases {
            let list = Settings.shared.learnedWordList(for: language.rawValue)
            if !list.isEmpty { result[language.rawValue] = list }
        }
        return result
    }

    private func remove(_ removed: [String], from language: Language) {
        for word in removed { Settings.shared.removeLearnedWord(word, for: language.rawValue) }
        var list = words[language.rawValue] ?? []
        list.removeAll { removed.contains($0) }
        Feedback.tick()
        withAnimation(.easeOut(duration: 0.2)) { words[language.rawValue] = list.isEmpty ? nil : list }
    }
}
