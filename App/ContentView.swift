import SwiftUI
import UIKit

/// The keyboard's settings, grouped like the system Settings app: what the keyboard does, how typing behaves, how
/// it looks and feels, and the data it keeps. Every section is its own small view, so changing one control only
/// redraws that section; rows that open a screen show what it is set to.
struct ContentView: View {
    /// The screens opened from the main list (ScreenRow pushes onto it).
    @State private var path: [Screen] = []
    @AppStorage(SettingKey.appLanguage, store: SharedStore.defaults) private var appLanguage = SettingDefault.appLanguage

    var body: some View {
        NavigationStack(path: $path) {
            // Liquid Glass: glass cards on the tinted backdrop (Glass.swift).
            GlassList {
                HeaderSection()
                TestFieldSection().glassRows()
                KeyboardSection().glassRows()
                TypingSection().glassRows()
                LookSection().glassRows()
                DataSection().glassRows()
                AboutSection().glassRows()
                AppLanguageSection().glassRows()
            }
            .glassScreen()
            .navigationTitle(tr("Iramo"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .navigationDestination(for: Screen.self) { $0.view }
        }
        // Everything is built again in the new language when it changes (tr reads it as the views are drawn).
        .id(appLanguage)
        .environment(\.locale, AppLanguage.locale)
        .environment(\.layoutDirection, AppLanguage.isRightToLeft ? .rightToLeft : .leftToRight)
        .environment(\.openScreen, { path.append($0) })
        .modifier(AccentTint())
        .onAppear {
            Feedback.prepare()
            Settings.shared.removeTouchModel()
        }
    }
}

// MARK: - Sections

/// The app icon, name and motto, and (only while something still needs doing) a note on setting it up.
private struct HeaderSection: View {
    @State private var status = KeyboardStatus.read()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            VStack(spacing: 10) {
                // The app icon (AppLogo is a small copy of it, written by scripts/make_icon.py), with the home
                // screen's corner shape.
                Image("AppLogo")
                    .resizable()
                    .frame(width: 78, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 17.5, style: .continuous))
                    .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
                    .accessibilityHidden(true)
                Text(tr("Iramo")).font(.largeTitle.weight(.bold))
                Text(tr("Your words, your keyboard"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .glassOutsideCard()

            // Only what still needs setting up is shown.
            if !status.isReady {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        IconTile(symbol: SharedStore.isShared ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath",
                                 color: SharedStore.isShared ? .orange : .red)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title).font(.headline)
                            Text(hint)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if SharedStore.isShared, let url = URL(string: UIApplication.openSettingsURLString) {
                        // The app's own page in Settings lists Keyboards > Iramo and Allow Full Access.
                        Button {
                            Feedback.tap()
                            openURL(url)
                        } label: {
                            Text(tr("Open Settings"))
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(Capsule().fill(.tint))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 6)
                .listRowBackground(GlassRowFill())
            }
        }
        // Read when the screen opens or the app comes back to the front - no polling.
        .onAppear { status = KeyboardStatus.read() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { status = KeyboardStatus.read() }
        }
    }

    private var title: String {
        if !SharedStore.isShared { return tr("Settings can't reach the keyboard") }
        return status.seen ? tr("Allow Full Access") : tr("Add the keyboard")
    }

    private var hint: String {
        if !SharedStore.isShared {
            return tr("This install can't share settings with the keyboard (no App Group). Install the IPA with iloader.")
        }
        if !status.seen {
            return tr("In Settings, open Keyboards, switch on Iramo and Allow Full Access, then open the keyboard once.")
        }
        return tr("Without it there is no vibration, and the keyboard can't save recent emoji or learned words.")
    }
}

private struct TestFieldSection: View {
    @State private var text = ""

    var body: some View {
        Section {
            HStack(spacing: 12) {
                IconTile(symbol: "keyboard", color: .gray)
                TextField(tr("Tap here and type to try it"), text: $text)
            }
        } header: {
            SectionHeader(tr("Try it"), symbol: "text.cursor", color: .gray)
        }
    }
}

/// Screens for what the keyboard does: languages, the suggestion bar, gestures, touch and shortcuts.
private struct KeyboardSection: View {
    // (A list can't be an @AppStorage value: read on appear, like the shortcuts.)
    @State private var languages = Settings.shared.enabledLanguages
    @AppStorage(SettingKey.suggestions, store: SharedStore.defaults) private var suggestions = SettingDefault.suggestions
    @AppStorage(SettingKey.suggestionFit, store: SharedStore.defaults) private var fit = SettingDefault.suggestionFit
    @AppStorage(SettingKey.suggestionScroll, store: SharedStore.defaults) private var scroll = SettingDefault.suggestionScroll
    @AppStorage(SettingKey.swipe, store: SharedStore.defaults) private var swipe = SettingDefault.swipe
    @AppStorage(SettingKey.hitboxSize, store: SharedStore.defaults) private var hitboxSize = SettingDefault.hitboxSize
    @AppStorage(SettingKey.adaptiveHitboxes, store: SharedStore.defaults) private var adaptive = SettingDefault.adaptiveHitboxes
    @State private var shortcutCount = Settings.shared.shortcuts.count

    private var languageSummary: String {
        let names = Language.list(from: languages).map { $0.localizedName }
        if names.count <= 2 { return names.joined(separator: ", ") }
        return "\(names[0]) +\(names.count - 1)"
    }

    private var barSummary: String {
        if !suggestions { return tr("Off") }
        return scroll ? tr("Scrolling") : (fit ? tr("Fit to words") : tr("Three words"))
    }

    private var touchSummary: String {
        let room = abs(hitboxSize - 0.85) < 0.001 ? tr("Strict") : (abs(hitboxSize - 1.2) < 0.001 ? tr("Generous") : tr("Normal"))
        return adaptive ? tr("%@, adaptive", "\(room)") : room
    }

    var body: some View {
        Section {
            ScreenRow(.languages) {
                SettingsRow(title: tr("Languages"), symbol: "globe", color: .blue, value: languageSummary)
            }
            ScreenRow(.suggestions) {
                SettingsRow(title: tr("Suggestion bar"), symbol: "text.line.first.and.arrowtriangle.forward", color: .indigo,
                            value: barSummary)
            }
            ScreenRow(.gestures) {
                SettingsRow(title: tr("Gestures"), symbol: "hand.draw.fill", color: .teal,
                            value: swipe && !Language.lacking(.swipe, among: Language.list(from: languages)).all ? tr("Swipe on") : tr("Swipe off"))
            }
            ScreenRow(.hitboxes) {
                SettingsRow(title: tr("Hitboxes"), symbol: "scope", color: .cyan, value: touchSummary)
            }
            ScreenRow(.shortcuts) {
                SettingsRow(title: tr("Text shortcuts"), symbol: "bolt.fill", color: .orange,
                            value: shortcutCount > 0 ? "\(shortcutCount)" : nil)
            }
            ScreenRow(.emoji) {
                SettingsRow(title: tr("Emoji"), symbol: "face.smiling.inverse", color: .yellow)
            }
            ScreenRow(.functions) {
                SettingsRow(title: tr("Functions panel"), symbol: "square.grid.2x2.fill", color: .pink)
            }
        } header: {
            SectionHeader(tr("Keyboard"), symbol: "keyboard", color: .blue)
        } footer: {
            Text(tr("Swipe the space bar left or right to switch languages."))
        }
        .onAppear {
            languages = Settings.shared.enabledLanguages
            shortcutCount = Settings.shared.shortcuts.count
        }
    }
}

private struct TypingSection: View {
    var body: some View {
        Section {
            SettingToggle(tr("Auto-correction"), key: SettingKey.autoCorrect, defaultValue: SettingDefault.autoCorrect,
                          subtitle: tr("Fixes typos, accents and missing spaces on space"),
                          symbol: "checkmark.seal.fill", color: .green, feature: .autoCorrect)
            SettingToggle(tr("Emoji suggestions"), key: SettingKey.emojiSuggestions, defaultValue: SettingDefault.emojiSuggestions,
                          subtitle: tr("An emoji that matches the word you typed"),
                          symbol: "face.smiling.inverse", color: .yellow)
            SettingToggle(tr("Auto-capitalization"), key: SettingKey.autoCapitalize, defaultValue: SettingDefault.autoCapitalize,
                          subtitle: tr("A capital at the start of each sentence"),
                          symbol: "textformat", color: .blue, feature: .capitals)
            SettingToggle(tr("\u{201C}.\u{201D} shortcut"), key: SettingKey.doubleSpacePeriod, defaultValue: SettingDefault.doubleSpacePeriod,
                          subtitle: tr("Tap the space bar twice to end a sentence"),
                          symbol: "circle.fill", color: .gray, feature: .sentencePeriod)
            SettingToggle(tr("Key pop-ups"), key: SettingKey.keyPopups, defaultValue: SettingDefault.keyPopups,
                          subtitle: tr("The letter shows above your finger"),
                          symbol: "rectangle.and.hand.point.up.left.fill", color: .purple)
        } header: {
            SectionHeader(tr("Typing"), symbol: "character.cursor.ibeam", color: .green)
        }
    }
}

/// The theme (its preview is on the Themes screen), the number row, the keys, haptics and the accent colour.
private struct LookSection: View {
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @AppStorage(SettingKey.keyHeight, store: SharedStore.defaults) private var keyHeight = SettingDefault.keyHeight
    @AppStorage(SettingKey.vibration, store: SharedStore.defaults) private var vibration = SettingDefault.vibration
    @AppStorage(SettingKey.hapticSharpness, store: SharedStore.defaults) private var sharpness = SettingDefault.hapticSharpness

    private var accent: Color { return Color.currentAccent(name: accentName, hex: accentHex) }
    private var theme: ThemeDefinition { return ThemeCatalog.theme(id: themeID) }

    private var hapticSummary: String {
        if vibration < 0.01 { return tr("Off") }
        return [tr("Soft"), tr("Light"), tr("Medium"), tr("Firm"), tr("Crisp")][min(4, max(0, Int(sharpness * 5)))]
    }

    var body: some View {
        Section {
            ScreenRow(.themes) {
                SettingsRow(title: tr("Theme"), symbol: "paintbrush.fill", color: .purple, value: theme.name)
            }
            SettingToggle(tr("Number row"), key: SettingKey.numberRow, defaultValue: SettingDefault.numberRow,
                          subtitle: tr("Numbers above the letters"), symbol: "number", color: .orange)
            ScreenRow(.keys) {
                SettingsRow(title: tr("Keys"), symbol: "square.grid.3x2.fill", color: .blue, value: "\(Int(keyHeight.rounded())) pt")
            }
            ScreenRow(.haptics) {
                SettingsRow(title: tr("Haptics"), symbol: "iphone.radiowaves.left.and.right", color: .pink, value: hapticSummary)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    IconTile(symbol: "drop.fill", color: accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Accent colour"))
                        Text(tr("Return key and highlights of the system themes; designed themes set theirs in the theme editor."))
                            .font(.footnote).foregroundColor(.secondary)
                    }
                }
                AccentPicker()
            }
            .padding(.vertical, 2)
        } header: {
            SectionHeader(tr("Look & feel"), symbol: "paintpalette.fill", color: .purple)
        }
    }
}

private struct DataSection: View {
    private enum Action: String {
        case recents, learned, reset

        var title: String {
            switch self {
            case .recents: return tr("Clear recent emoji?")
            case .learned: return tr("Forget learned words?")
            case .reset: return tr("Reset all settings?")
            }
        }

        var message: String {
            switch self {
            case .recents: return tr("The Recently Used emoji tab will be empty.")
            case .learned: return tr("Words the keyboard picked up while you type will be removed.")
            case .reset: return tr("Your shortcuts, recent emoji and learned words are kept.")
            }
        }

        var button: String {
            switch self {
            case .recents: return tr("Clear")
            case .learned: return tr("Forget")
            case .reset: return tr("Reset")
            }
        }
    }

    @State private var pending: Action?
    @State private var note: String?
    @State private var learnedCount = 0

    var body: some View {
        Section {
            ScreenRow(.learnedWords) {
                SettingsRow(title: tr("Learned words"), symbol: "character.book.closed", color: .brown,
                            value: learnedCount > 0 ? "\(learnedCount)" : nil)
            }
            // Orange: they remove things (each asks first), short of red Reset, which undoes every setting.
            row(.learned, tr("Forget learned words"), symbol: "text.book.closed", color: .orange)
            row(.recents, tr("Clear recent emoji"), symbol: "clock.arrow.circlepath", color: .orange)
            row(.reset, tr("Reset all settings"), symbol: "arrow.counterclockwise", color: .red, role: .destructive)
            if let note = note {
                Text(note).font(.footnote).foregroundColor(.secondary)
            }
        } header: {
            SectionHeader(tr("Privacy & data"), symbol: "hand.raised.fill", color: .gray)
        } footer: {
            Text(tr("Everything the keyboard learns stays on this device."))
        }
        .onAppear { learnedCount = DataSection.countLearned() }
    }

    private static func countLearned() -> Int {
        return Settings.shared.learnedWordList().count
    }

    /// One option with its own confirmation, so the dialog's arrow points at the option that was tapped.
    private func row(_ action: Action, _ title: String, symbol: String, color: Color, role: ButtonRole? = nil) -> some View {
        Button(role: role) {
            // Resetting everything warns with a long, strong buzz before the question; the others a soft tap.
            if action == .reset { Feedback.danger() } else { Feedback.tap() }
            pending = action
        } label: {
            HStack(spacing: 12) {
                IconTile(symbol: symbol, color: color)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(role == .destructive ? .red : color)
            }
        }
            .confirmationDialog(action.title,
                                isPresented: Binding(get: { pending == action }, set: { if !$0 { pending = nil } }),
                                titleVisibility: .visible) {
                Button(action.button, role: .destructive) { perform(action) }
                Button(tr("Cancel"), role: .cancel) {}
            } message: {
                Text(action.message)
            }
    }

    private func perform(_ action: Action) {
        switch action {
        case .recents:
            Settings.shared.clearRecentEmoji()
            note = tr("Recent emoji cleared.")
        case .learned:
            Settings.shared.clearLearnedWords()
            learnedCount = 0
            note = tr("Learned words forgotten.")
        case .reset:
            Settings.shared.resetPreferences()
            NotificationCenter.default.post(name: .hunKeysSettingsReset, object: nil)
            note = tr("Settings reset to defaults.")
        }
        if action == .reset { Feedback.warning() } else { Feedback.delete() }
    }
}

/// Credits and licences for the word data, emoji data and icons the app ships (LicensesView).
private struct AboutSection: View {
    var body: some View {
        Section {
            ScreenRow(.licences) {
                SettingsRow(title: tr("Licences"), symbol: "doc.text.fill", color: .gray)
            }
        } header: {
            SectionHeader(tr("About"), symbol: "info.circle", color: .gray)
        } footer: {
            Text(tr("Iramo. Copyright \u{00A9} 2026 Ors\u{00F3}s Emil."))
        }
    }
}

/// The app's own language, last on the main screen: the phone's or any of the keyboard's languages, each named
/// in the app's current language (with its own name beside it, to find one's way back).
private struct AppLanguageSection: View {
    @AppStorage(SettingKey.appLanguage, store: SharedStore.defaults) private var appLanguage = SettingDefault.appLanguage

    /// The languages by their names in the app's language.
    private var languages: [Language] {
        let locale = AppLanguage.locale
        return Language.allCases.sorted {
            $0.localizedName.compare($1.localizedName, options: [.caseInsensitive], range: nil, locale: locale) == .orderedAscending
        }
    }

    private func name(_ language: Language) -> String {
        let name = language.localizedName
        return name == language.displayName ? name : "\(name) (\(language.displayName))"
    }

    var body: some View {
        Section {
            Picker(selection: Binding(get: { appLanguage }, set: { value in
                guard value != appLanguage else { return }
                Feedback.choose()
                appLanguage = value
            })) {
                Text(tr("System (%@)", "\(AppLanguage.systemLanguage.localizedName)")).tag(AppLanguage.system)
                ForEach(languages, id: \.self) { language in
                    Text(name(language)).tag(language.rawValue)
                }
            } label: {
                HStack(spacing: 12) {
                    IconTile(symbol: "globe", color: .blue)
                    Text(tr("App language"))
                }
            }
            .pickerStyle(.menu)
        } header: {
            SectionHeader(tr("Language"), symbol: "character.bubble.fill", color: .blue)
        } footer: {
            Text(tr("The language of this app. The keyboard's typing languages are set under Languages."))
        }
    }
}

// MARK: - Screens

/// The screens the main list opens.
enum Screen: Hashable {
    case languages, suggestions, gestures, hitboxes, shortcuts, emoji, functions, themes, themeEditor, keys, haptics, learnedWords, licences

    @ViewBuilder var view: some View {
        switch self {
        case .languages: LanguagesView()
        case .suggestions: SuggestionsView()
        case .gestures: GesturesView()
        case .hitboxes: HitboxesView()
        case .shortcuts: ShortcutsView()
        case .emoji: EmojiView()
        case .functions: FunctionsView()
        case .themes: ThemesView()
        case .themeEditor: ThemeEditorView()
        case .keys: KeysView()
        case .haptics: HapticsView()
        case .learnedWords: LearnedWordsView()
        case .licences: LicensesView()
        }
    }
}

private struct OpenScreenKey: EnvironmentKey {
    static let defaultValue: (Screen) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Opens a screen of the main list (set by ContentView).
    var openScreen: (Screen) -> Void {
        get { return self[OpenScreenKey.self] }
        set { self[OpenScreenKey.self] = newValue }
    }
}

/// A row that opens a screen: the whole row is one button (a soft tap, then the screen), with the disclosure arrow
/// on the right. A plain button rather than a NavigationLink with an extra tap gesture, which in a list could take
/// the tap and leave the screen unopened.
struct ScreenRow<Label: View>: View {
    let screen: Screen
    @ViewBuilder let label: () -> Label
    @Environment(\.openScreen) private var openScreen

    init(_ screen: Screen, @ViewBuilder label: @escaping () -> Label) {
        self.screen = screen
        self.label = label
    }

    var body: some View {
        Button {
            Feedback.tap()
            openScreen(screen)
        } label: {
            HStack(spacing: 8) {
                label()
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .foregroundColor(.primary)
            .contentShape(Rectangle())
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

    // A Liquid Glass list like the main screen's (the shortcuts swipe to delete); the example of the shortcut being
    // typed stays pinned above it (PinnedPreview).
    var body: some View {
        PinnedPreview(id: "shortcuts", height: 110) {
            ShortcutPreview(trigger: trigger, phrase: phrase)
        } content: {
        GlassList {
            Section {
                TextField(tr("Trigger (e.g. omw)"), text: $trigger)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                TextField(tr("Phrase (e.g. On my way!)"), text: $phrase)
                Button(tr("Add"), action: add)
                    .disabled(!canAdd)
            } header: {
                Text(tr("New shortcut"))
            }
            .glassRows()

            Section {
                if items.isEmpty {
                    Text(tr("None yet")).foregroundColor(.secondary)
                } else {
                    ForEach(items, id: \.id) { item in
                        VStack(alignment: .leading) {
                            Text(item.trigger).font(.headline)
                            Text(item.phrase).font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                        .swipeToDelete { remove(item) }
                    }
                }
            } header: {
                Text(tr("Your shortcuts"))
            } footer: {
                if !items.isEmpty { Text(tr("Swipe a shortcut left to remove it.")) }
            }
            .glassRows()
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(tr("Text shortcuts"))
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
        Feedback.success()
        trigger = ""
        phrase = ""
    }

    private func remove(_ item: TextShortcut) {
        Feedback.delete()
        withAnimation(.easeOut(duration: 0.2)) { items.removeAll { $0.id == item.id } }
        save()
    }

    private func save() {
        Settings.shared.shortcuts = items
    }
}

// MARK: - Languages

/// The enabled languages only; more are added from a separate list. A Liquid Glass list like the main screen's;
/// a language swipes left to delete, the Delete button inside its row.
struct LanguagesView: View {
    @State private var enabled: [String] = Settings.shared.enabledLanguages

    private var languages: [Language] { return enabled.compactMap { Language(rawValue: $0) } }

    var body: some View {
        GlassList {
            Section {
                ForEach(languages, id: \.rawValue) { language in
                    Text(language.localizedName)
                    .swipeToDelete(enabled: languages.count > 1) { remove(language) }
                }
            } footer: {
                Text(tr("Swipe the space bar left or right to switch. Swipe a language left to remove it."))
            }
            .glassRows()

            if enabled.count < Language.allCases.count {
                Section {
                    NavigationLink {
                        AddLanguageView(enabled: enabled) { language in
                            save(enabled + [language.rawValue])
                        }
                    } label: {
                        HStack {
                            Label(tr("Add a language"), systemImage: "plus")
                            Spacer()
                            DisclosureChevron()
                        }
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
        .onAppear { enabled = Settings.shared.enabledLanguages }
    }

    private func remove(_ language: Language) {
        guard enabled.count > 1 else { return }
        save(enabled.filter { $0 != language.rawValue })
    }

    private func save(_ list: [String]) {
        let ordered = Language.allCases.map { $0.rawValue }.filter { list.contains($0) }
        guard !ordered.isEmpty, ordered != enabled else { return }
        if ordered.count > enabled.count { Feedback.success() } else { Feedback.delete() }
        withAnimation(.easeOut(duration: 0.2)) { enabled = ordered }
        Settings.shared.enabledLanguages = ordered
    }
}

/// The languages that are not enabled yet; picking one adds it and goes back.
private struct AddLanguageView: View {
    let enabled: [String]
    let add: (Language) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GlassList {
            ForEach(Language.allCases.filter { !enabled.contains($0.rawValue) }, id: \.rawValue) { language in
                Button {
                    add(language)
                    dismiss()
                } label: {
                    Text(language.localizedName)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
            .glassRows()
        }
        .glassScreen()
        .navigationTitle(tr("Add a language"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Learned words

/// Words the keyboard learned (ones no dictionary has, used at least twice), one list for every language, with a
/// search field and swipe to remove.
struct LearnedWordsView: View {
    @State private var words: [String] = []
    @State private var query = ""

    /// The words that match the search.
    private var matches: [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return words }
        return words.filter { $0.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    // A Liquid Glass list like the main screen's; a word swipes left to delete.
    var body: some View {
        GlassList {
            Section {
                if words.isEmpty {
                    Text(tr("No learned words yet")).foregroundColor(.secondary)
                } else if matches.isEmpty {
                    Text(tr("No matching words")).foregroundColor(.secondary)
                } else {
                    ForEach(matches, id: \.self) { word in
                        Text(word)
                            .swipeToDelete { remove(word) }
                    }
                }
            } footer: {
                if words.isEmpty {
                    Text(tr("A word that isn't in the dictionary is learned once you have typed it twice, or when you tap it in the suggestion bar. Learned words work in every language."))
                } else if !matches.isEmpty {
                    Text(tr("Learned words work in every language. Swipe a word left to remove it."))
                }
            }
            .glassRows()
        }
        .glassScreen()
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: tr("Search learned words"))
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .navigationTitle(tr("Learned words"))
        .navigationBarTitleDisplayMode(.inline)
        // Reloaded on every visit: a NavigationLink builds this view's initial state only once.
        .onAppear { words = Settings.shared.learnedWordList() }
    }

    private func remove(_ word: String) {
        Settings.shared.removeLearnedWord(word)
        Feedback.delete()
        withAnimation(.easeOut(duration: 0.2)) { words.removeAll { $0 == word } }
    }
}

/// What a shortcut does, as the suggestion bar shows it: the trigger typed (on a key of the theme), then the phrase
/// space will write (on the theme's accent pill).
private struct ShortcutPreview: View {
    let trigger: String
    let phrase: String

    var body: some View {
        let typed = trigger.trimmingCharacters(in: .whitespaces)
        let written = phrase.trimmingCharacters(in: .whitespaces)
        PreviewCard(caption: tr("Type the trigger and press space: the phrase takes its place.")) {
            CurrentThemeLook { look in
                HStack(spacing: 10) {
                    Text(typed.isEmpty ? "omw" : typed)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(look.textColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(look.keyShape(.letter, radius: 8))
                    Image(systemName: "arrow.right")
                        .foregroundColor(look.stripText.opacity(0.6))
                    Text(written.isEmpty ? tr("On my way!") : written)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(look.onAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(look.pill(radius: 15))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .opacity(typed.isEmpty && written.isEmpty ? 0.6 : 1)
            }
        }
    }
}
