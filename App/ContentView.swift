import SwiftUI
import UIKit

/// The keyboard's settings, grouped like the system Settings app: what the keyboard does, how typing behaves, how
/// it looks and feels, and the data it keeps. Every section is its own small view, so changing one control only
/// redraws that section; rows that open a screen show what it is set to.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            // Liquid Glass: frosted rows on the tinted backdrop (Glass.swift).
            List {
                HeaderSection()
                TestFieldSection().glassRows()
                KeyboardSection().glassRows()
                TypingSection().glassRows()
                LookSection().glassRows()
                DataSection().glassRows()
                AboutSection().glassRows()
            }
            .listStyle(.insetGrouped)
            .glassScreen()
            .navigationTitle("Iramo")
            .navigationBarTitleDisplayMode(.inline)
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
                Text("Iramo").font(.largeTitle.weight(.bold))
                Text("Your words, your keyboard")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)

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
                            Text("Open Settings")
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
        if !SharedStore.isShared { return "Settings can't reach the keyboard" }
        return status.seen ? "Allow Full Access" : "Add the keyboard"
    }

    private var hint: String {
        if !SharedStore.isShared {
            return "This install can't share settings with the keyboard (no App Group). Install the IPA with iloader."
        }
        if !status.seen {
            return "In Settings, open Keyboards, switch on Iramo and Allow Full Access, then open the keyboard once."
        }
        return "Without it there is no vibration, and the keyboard can't save recent emoji or learned words."
    }
}

private struct TestFieldSection: View {
    @State private var text = ""

    var body: some View {
        Section {
            HStack(spacing: 12) {
                IconTile(symbol: "keyboard", color: .gray)
                TextField("Tap here and type to try it", text: $text)
            }
        } header: {
            SectionHeader("Try it", symbol: "text.cursor", color: .gray)
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
        let names = Language.list(from: languages).map { $0.displayName }
        if names.count <= 2 { return names.joined(separator: ", ") }
        return "\(names[0]) +\(names.count - 1)"
    }

    private var barSummary: String {
        if !suggestions { return "Off" }
        return scroll ? "Scrolling" : (fit ? "Fit to words" : "Three words")
    }

    private var touchSummary: String {
        let room = abs(hitboxSize - 0.85) < 0.001 ? "Strict" : (abs(hitboxSize - 1.2) < 0.001 ? "Generous" : "Normal")
        return adaptive ? "\(room), adaptive" : room
    }

    var body: some View {
        Section {
            NavigationLink { LanguagesView() } label: {
                SettingsRow(title: "Languages", symbol: "globe", color: .blue, value: languageSummary)
            }
            .hapticTap()
            NavigationLink { SuggestionsView() } label: {
                SettingsRow(title: "Suggestion bar", symbol: "text.line.first.and.arrowtriangle.forward", color: .indigo,
                            value: barSummary)
            }
            .hapticTap()
            NavigationLink { GesturesView() } label: {
                SettingsRow(title: "Gestures", symbol: "hand.draw.fill", color: .teal, value: swipe ? "Swipe on" : "Swipe off")
            }
            .hapticTap()
            NavigationLink { HitboxesView() } label: {
                SettingsRow(title: "Hitboxes", symbol: "scope", color: .cyan, value: touchSummary)
            }
            .hapticTap()
            NavigationLink { ShortcutsView() } label: {
                SettingsRow(title: "Text shortcuts", symbol: "bolt.fill", color: .orange,
                            value: shortcutCount > 0 ? "\(shortcutCount)" : nil)
            }
            .hapticTap()
        } header: {
            SectionHeader("Keyboard", symbol: "keyboard", color: .blue)
        } footer: {
            Text("Swipe the space bar left or right to switch languages.")
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
            SettingToggle("Auto-correction", key: SettingKey.autoCorrect, defaultValue: SettingDefault.autoCorrect,
                          subtitle: "Fixes typos, accents and missing spaces on space",
                          symbol: "checkmark.seal.fill", color: .green)
            SettingToggle("Emoji suggestions", key: SettingKey.emojiSuggestions, defaultValue: SettingDefault.emojiSuggestions,
                          subtitle: "An emoji that matches the word you typed",
                          symbol: "face.smiling.inverse", color: .yellow)
            SettingToggle("Auto-capitalization", key: SettingKey.autoCapitalize, defaultValue: SettingDefault.autoCapitalize,
                          subtitle: "A capital at the start of each sentence",
                          symbol: "textformat", color: .blue)
            SettingToggle("\u{201C}.\u{201D} shortcut", key: SettingKey.doubleSpacePeriod, defaultValue: SettingDefault.doubleSpacePeriod,
                          subtitle: "Tap the space bar twice to end a sentence",
                          symbol: "circle.fill", color: .gray)
            SettingToggle("Key pop-ups", key: SettingKey.keyPopups, defaultValue: SettingDefault.keyPopups,
                          subtitle: "The letter shows above your finger",
                          symbol: "rectangle.and.hand.point.up.left.fill", color: .purple)
        } header: {
            SectionHeader("Typing", symbol: "character.cursor.ibeam", color: .green)
        }
    }
}

/// The theme (with a live preview), the keys, haptics and the accent colour.
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
        if vibration < 0.01 { return "Off" }
        return ["Soft", "Light", "Medium", "Firm", "Crisp"][min(4, max(0, Int(sharpness * 5)))]
    }

    var body: some View {
        Section {
            NavigationLink { ThemesView() } label: {
                VStack(alignment: .leading, spacing: 12) {
                    ThemePreview(theme: theme, accent: accent, cornerRadius: 12)
                        .aspectRatio(ThemePreview.aspectWithStrip, contentMode: .fit)
                        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                    SettingsRow(title: "Theme", symbol: "paintbrush.fill", color: .purple, value: theme.name)
                }
                .padding(.vertical, 6)
            }
            .hapticTap()
            NavigationLink { KeysView() } label: {
                SettingsRow(title: "Keys", symbol: "square.grid.3x2.fill", color: .blue, value: "\(Int(keyHeight.rounded())) pt")
            }
            .hapticTap()
            NavigationLink { HapticsView() } label: {
                SettingsRow(title: "Haptics", symbol: "iphone.radiowaves.left.and.right", color: .pink, value: hapticSummary)
            }
            .hapticTap()
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    IconTile(symbol: "drop.fill", color: accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accent colour")
                        Text("Return key and highlights; colour themes keep their own until you pick one.")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                }
                AccentPicker()
            }
            .padding(.vertical, 2)
            AccentCustomRow()
            SettingToggle("Number row", key: SettingKey.numberRow, defaultValue: SettingDefault.numberRow,
                          subtitle: "Numbers above the letters", symbol: "number", color: .orange)
        } header: {
            SectionHeader("Look & feel", symbol: "paintpalette.fill", color: .purple)
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
    @State private var learnedCount = 0

    var body: some View {
        Section {
            NavigationLink {
                LearnedWordsView()
            } label: {
                SettingsRow(title: "Learned words", symbol: "character.book.closed", color: .brown,
                            value: learnedCount > 0 ? "\(learnedCount)" : nil)
            }
            .hapticTap()
            // Orange: they remove things (each asks first), short of red Reset, which undoes every setting.
            row(.learned, "Forget learned words", symbol: "text.book.closed", color: .orange)
            row(.recents, "Clear recent emoji", symbol: "clock.arrow.circlepath", color: .orange)
            row(.reset, "Reset all settings", symbol: "arrow.counterclockwise", color: .red, role: .destructive)
            if let note = note {
                Text(note).font(.footnote).foregroundColor(.secondary)
            }
        } header: {
            SectionHeader("Privacy & data", symbol: "hand.raised.fill", color: .gray)
        } footer: {
            Text("Everything the keyboard learns stays on this device.")
        }
        .onAppear { learnedCount = DataSection.countLearned() }
    }

    private static func countLearned() -> Int {
        return Language.allCases.reduce(0) { $0 + Settings.shared.learnedWordList(for: $1.rawValue).count }
    }

    /// One option with its own confirmation, so the dialog's arrow points at the option that was tapped.
    private func row(_ action: Action, _ title: String, symbol: String, color: Color, role: ButtonRole? = nil) -> some View {
        Button(role: role) {
            Feedback.tap()
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
            learnedCount = 0
            note = "Learned words forgotten."
        case .reset:
            Settings.shared.resetPreferences()
            NotificationCenter.default.post(name: .hunKeysSettingsReset, object: nil)
            note = "Settings reset to defaults."
        }
        if action == .reset { Feedback.warning() } else { Feedback.delete() }
    }
}

/// Credits and licences for the word data, emoji data and icons the app ships (LicensesView).
private struct AboutSection: View {
    var body: some View {
        Section {
            NavigationLink { LicensesView() } label: {
                SettingsRow(title: "Licences", symbol: "doc.text.fill", color: .gray)
            }
            .hapticTap()
        } header: {
            SectionHeader("About", symbol: "info.circle", color: .gray)
        } footer: {
            Text("Iramo. Copyright \u{00A9} 2026 Ors\u{00F3}s Emil.")
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

    // Grouped cards rather than a Form, so the shortcuts swipe to delete like the languages do; the example of
    // the shortcut being typed stays pinned above them (PinnedPreview).
    var body: some View {
        PinnedPreview(id: "shortcuts", height: 110) {
            ShortcutPreview(trigger: trigger, phrase: phrase)
        } content: {
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
        }
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

/// The enabled languages only; more are added from a separate list. Drawn as its own grouped card (not a List)
/// so the swipe-to-delete button sits inside the row and the card keeps its corners while swiping.
struct LanguagesView: View {
    @State private var enabled: [String] = Settings.shared.enabledLanguages

    private var languages: [Language] { return enabled.compactMap { Language(rawValue: $0) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                DeletableCard(items: languages, id: { $0.rawValue }, canDelete: languages.count > 1, onDelete: remove) { language in
                    // The language and its layout (the first letters of its top row).
                    HStack {
                        Text(language.displayName)
                        Spacer()
                        Text(ThemePreview.letterRows(for: language)[0].prefix(6).joined().uppercased())
                            .font(.footnote.monospaced())
                            .foregroundColor(.secondary)
                    }
                    .cardRow()
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
        if ordered.count > enabled.count { Feedback.success() } else { Feedback.delete() }
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

/// The title above a grouped card, styled like the list sections' headers (SectionHeader).
private struct CardHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 16)
            .padding(.top, 4)
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
                if (offset > -maxReveal) != (resisted > -maxReveal) { Feedback.threshold() }   // crossing it
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
        Feedback.delete()
        withAnimation(.easeOut(duration: 0.2)) { words[language.rawValue] = list.isEmpty ? nil : list }
    }
}

/// What a shortcut does, as the suggestion bar shows it: the trigger typed, then the phrase space will write.
private struct ShortcutPreview: View {
    let trigger: String
    let phrase: String

    var body: some View {
        let typed = trigger.trimmingCharacters(in: .whitespaces)
        let written = phrase.trimmingCharacters(in: .whitespaces)
        PreviewCard(caption: "Type the trigger and press space: the phrase takes its place.") {
            HStack(spacing: 10) {
                Text(typed.isEmpty ? "omw" : typed)
                    .font(.system(size: 15, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(.systemBackground)))
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                Text(written.isEmpty ? "On my way!" : written)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.tint))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .opacity(typed.isEmpty && written.isEmpty ? 0.6 : 1)
        }
    }
}
